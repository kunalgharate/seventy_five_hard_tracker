import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles Firebase Cloud Messaging for push notifications.
///
/// Background messages are handled by [firebaseMessagingBackgroundHandler]
/// which must be a top-level function.
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

  /// Call once after Firebase.initializeApp.
  Future<void> init() async {
    // Request permission (Android 13+ & iOS)
    await _messaging.requestPermission();

    // Create high-importance Android channel for heads-up display
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
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

    // Subscribe to default topic for broadcast messages
    await _messaging.subscribeToTopic('all_users');

    // Log FCM token for testing
    final token = await _messaging.getToken();
    // ignore: avoid_print
    if (kDebugMode) print('🔔 FCM Token: $token');
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Show as local notification since foreground messages
    // don't display automatically on Android
    await _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? '75 Hard Challenge',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.max,
          icon: 'ic_notification',
          sound: RawResourceAndroidNotificationSound('notification'),
          playSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Handle deep-link / navigation from notification data
    // e.g., message.data['screen'] → navigate accordingly
    // ignore: avoid_print
    if (kDebugMode) print('🔔 FCM tap data: ${message.data}');
  }
}
