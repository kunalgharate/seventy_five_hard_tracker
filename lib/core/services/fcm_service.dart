import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_bloc.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/pages/accountability_chat_screen.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/widgets/reviews_tab.dart';
import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/widgets/custom_app_bar.dart';

import 'notification_dispatch_listener.dart';

/// Handles Firebase Cloud Messaging for push notifications.
///
/// Background messages are handled by [firebaseMessagingBackgroundHandler]
/// which must be a top-level function.
///
/// Delivery of accountability notifications is client-only (no Cloud
/// Functions): senders write `fcm_notifications` docs and
/// [NotificationDispatchListener] shows them via [showTrackedNotification].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await FcmService.instance._showLocalNotification(message);
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'fcm_push';
  static const _channelName = 'Push Notifications';

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.max,
      icon: 'ic_notification',
      sound: RawResourceAndroidNotificationSound('notification'),
      playSound: true,
    ),
  );

  /// Payload waiting for a stable navigator route. Cold-start taps are
  /// queued here and flushed by [main] once the splash pushes /home
  /// (see [appNavigationReady]) so the splash hand-off cannot replace the
  /// screen the tap asked for.
  String? _pendingPayload;

  /// Dedupes the same tap arriving through two paths (initialMessage +
  /// local-notification launch details).
  String? _lastQueuedPayload;
  DateTime? _lastQueuedAt;

  /// Last uid this device's FCM token was registered for.
  String? _registeredUid;

  /// Call once after Firebase.initializeApp.
  Future<void> init() async {
    // Request permission (Android 13+ & iOS)
    await _messaging.requestPermission();

    // Create high-importance Android channel for heads-up display
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Push notifications from 75 Hard Challenge',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification'),
        ),
      );
    }

    // Wire tap handling for notifications shown by this plugin (permission
    // was already requested by SmartNotificationService, so don't re-prompt).
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _queuePayloadString(response.payload),
    );

    // Tap that launched the app from a terminated state.
    try {
      final launch =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _queuePayloadString(launch?.notificationResponse?.payload);
      }
    } catch (_) {}

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background handler (top-level function)
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    // Handle notification tap when app was terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Subscribe to default topic for broadcast messages (non-blocking)
    _messaging.subscribeToTopic('all_users').catchError((_) {});

    // Persist this device's token on the signed-in user's doc, keep it
    // fresh, and deliver undelivered fcm_notifications docs locally.
    _initTokenRegistration();
    NotificationDispatchListener.instance.start();

    // A queued cold-start tap may have been discovered after main already
    // flushed (Firebase can init late) — flush again now that we're ready.
    if (appNavigationReady) unawaited(flushPendingNavigation());
  }

  // ── Device token registration ──────────────────────────────────────────

  void _initTokenRegistration() {
    _messaging.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) unawaited(_persistToken(token, uid));
    });
    FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid;
      if (uid == _registeredUid) return;
      _registeredUid = uid;
      if (uid != null) unawaited(_registerToken());
    });
    // Covers the already-signed-in-at-init case even if the auth stream
    // only emits on the next state change.
    unawaited(_registerToken());
  }

  /// Fetches this device's FCM token and stores it on `users/{uid}` so a
  /// future server-side sender can target this device. Failures are
  /// swallowed — delivery degrades to the in-app Firestore listener.
  Future<void> _registerToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _persistToken(token, uid);
      if (kDebugMode) print('🔔 FCM Token: $token');
    } catch (e) {
      if (kDebugMode) debugPrint('[Fcm] token register failed: $e');
    }
  }

  Future<void> _persistToken(String token, String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[Fcm] token persist failed: $e');
    }
  }

  /// Removes this device's token from the current user's `users` doc.
  /// MUST be called before FirebaseAuth.signOut() — security rules only let
  /// the owner update their own doc (cross-account isolation: the next
  /// account on this device must not inherit our pushes).
  Future<void> unregisterCurrentDeviceToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));
      _registeredUid = null;
    } catch (e) {
      if (kDebugMode) debugPrint('[Fcm] token unregister failed: $e');
    }
  }

  // ── Task channels (FCM topics) ─────────────────────────────────────────

  /// Subscribes this device to a task's FCM topic (topic name == the
  /// `channel` string stored on notification docs). Publishing to topics
  /// needs a server, but the subscription is correct prep for
  /// multi-reviewer broadcast.
  Future<void> subscribeToTaskChannel(String taskId) =>
      _messaging.subscribeToTopic('task_$taskId').catchError((_) {});

  Future<void> unsubscribeFromTaskChannel(String taskId) =>
      _messaging.unsubscribeFromTopic('task_$taskId').catchError((_) {});

  // ── Local notifications ────────────────────────────────────────────────

  /// Shows a local notification whose id is derived from [tag] — the
  /// channel string (e.g. `task_<taskId>`) — so repeated events for the
  /// same task REPLACE the existing notification instead of stacking one
  /// per event.
  Future<void> showTrackedNotification({
    required String tag,
    required String title,
    required String body,
    required String payloadJson,
  }) =>
      _localNotifications.show(
        notificationIdForTag(tag),
        title,
        body,
        _notificationDetails,
        payload: payloadJson,
      );

  /// Stable 31-bit FNV-1a id — same tag always maps to the same id.
  static int notificationIdForTag(String tag) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(tag)) {
      hash ^= unit;
      hash = (0x01000193 * hash) & 0x7fffffff;
    }
    return hash;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Show as local notification since foreground messages
    // don't display automatically on Android
    await _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final tag = message.data['channel'] as String?;
    await _localNotifications.show(
      tag != null ? notificationIdForTag(tag) : notification.hashCode,
      notification.title ?? '75 Hard Challenge',
      notification.body ?? '',
      _notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  // ── Tap → deep navigation ──────────────────────────────────────────────

  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) print('🔔 FCM tap data: ${message.data}');
    _queuePayloadMap(message.data);
  }

  void _queuePayloadString(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _queuePayloadMap(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
  }

  void _queuePayloadMap(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    final raw = jsonEncode(data);
    final now = DateTime.now();
    if (_lastQueuedPayload == raw &&
        now.difference(_lastQueuedAt ?? now).abs() <
            const Duration(seconds: 3)) {
      return;
    }
    _lastQueuedPayload = raw;
    _lastQueuedAt = now;
    _pendingPayload = raw;
    if (appNavigationReady) unawaited(flushPendingNavigation());
  }

  /// Navigates for the queued notification payload. [main]'s splash hand-off
  /// calls this once /home is up; after that taps flush immediately.
  Future<void> flushPendingNavigation() async {
    final raw = _pendingPayload;
    if (raw == null) return;
    final nav = navigatorKey.currentState;
    final ctx = navigatorKey.currentContext;
    if (nav == null || ctx == null) return;
    _pendingPayload = null;

    Map<String, dynamic> data;
    try {
      data = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }

    final type = data['type'] as String? ?? '';
    if (_isPartnerMessage(type)) {
      _openPartnerChat(nav, data);
    } else if (_isReviewType(type)) {
      _openReviews(nav, ctx);
    } else {
      nav.pushNamed('/home');
    }
  }

  // Payload types are canonical snake_case (single source of truth in
  // AccountabilityNotificationService); the legacy camelCase 'partnerMessage'
  // spelling only ever appeared on legacy doc top-level fields, which the
  // dispatch listener normalizes before the payload is queued here.
  bool _isPartnerMessage(String type) => type == 'partner_message';

  bool _isReviewType(String type) =>
      type.startsWith('task') ||
      type.startsWith('proof') ||
      type.startsWith('review') ||
      type.startsWith('invitation') ||
      type.startsWith('request');

  /// Pushes the Reviews screen exactly as the Squad top-right button does.
  void _openReviews(NavigatorState nav, BuildContext ctx) {
    final bloc = ctx.read<AccountabilityBloc>();
    nav.push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: const Scaffold(
            appBar: CustomAppBar(title: 'Reviews'),
            body: ReviewsTabV2(),
          ),
        ),
      ),
    );
  }

  void _openPartnerChat(NavigatorState nav, Map<String, dynamic> data) {
    final partnershipId = data['partnershipId'] as String? ?? '';
    final senderUid = data['senderUid'] as String? ?? '';
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (partnershipId.isEmpty ||
        myUid == null ||
        senderUid.isEmpty ||
        senderUid == myUid) {
      nav.pushNamed('/home');
      return;
    }
    // The chat screen only needs the partnership id plus a display name —
    // build a minimal partner view from the notification payload.
    nav.push(
      MaterialPageRoute(
        builder: (_) => AccountabilityChatScreen(
          partner: AccountabilityPartner(
            id: partnershipId,
            ownerUid: senderUid,
            partnerUid: myUid,
            partnerName: data['senderName'] as String? ?? 'Partner',
            role: PartnerRole.friend,
            status: PartnershipStatus.accepted,
            inviteCode: '',
            createdAt: DateTime.now(),
          ),
        ),
      ),
    );
  }
}
