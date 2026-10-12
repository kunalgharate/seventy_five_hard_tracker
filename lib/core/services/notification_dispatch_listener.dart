import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'fcm_service.dart';

/// Client-side delivery half of the notification pipeline documented in
/// [AccountabilityNotificationService] (Cloud Functions are unavailable):
/// a sender writes an `fcm_notifications` doc with `delivered: false`;
/// the recipient's app listens for those docs, shows a local notification
/// and then marks the doc `delivered: true` (which also feeds home_screen's
/// delivered-only inline reader).
///
/// Runs only while a user is signed in and stops on sign-out so the next
/// account on this device never sees the previous account's pending
/// notifications.
///
/// The two equality filters (`recipientUid`, `delivered`) are covered by
/// the existing composite index in firestore.indexes.json.
class NotificationDispatchListener {
  NotificationDispatchListener._();
  static final NotificationDispatchListener instance =
      NotificationDispatchListener._();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final Set<String> _inFlight = {};
  String? _uid;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    FirebaseAuth.instance
        .authStateChanges()
        .listen((user) => _onAuth(user?.uid), onError: (_) {});
  }

  void _onAuth(String? uid) {
    if (uid == _uid) return;
    _sub?.cancel();
    _sub = null;
    _uid = uid;
    if (uid == null) return;
    _sub = FirebaseFirestore.instance
        .collection('fcm_notifications')
        .where('recipientUid', isEqualTo: uid)
        .where('delivered', isEqualTo: false)
        .snapshots()
        .listen(_onSnapshot, onError: (Object e) {
      if (kDebugMode) {
        debugPrint('[NotificationDispatch] snapshot error: $e');
      }
    });
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added &&
          change.type != DocumentChangeType.modified) {
        continue;
      }
      unawaited(_dispatch(change.doc));
    }
  }

  Future<void> _dispatch(DocumentSnapshot<Map<String, dynamic>> doc) async {
    if (!_inFlight.add(doc.id)) return;
    try {
      final data = doc.data() ?? {};
      final notifData =
          (data['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      final channel = data['channel'] as String? ?? doc.id;
      final payload = <String, dynamic>{
        ...notifData,
        // The snake_case data type drives navigation; fall back to the
        // enum name for docs written before `data.type` existed.
        'type': notifData['type'] ?? data['type'] ?? '',
        'channel': channel,
      };
      await FcmService.instance.showTrackedNotification(
        tag: channel,
        title: data['title'] as String? ?? '75 Hard Challenge',
        body: data['body'] as String? ?? '',
        payloadJson: jsonEncode(payload),
      );
      await doc.reference.update({
        'delivered': true,
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationDispatch] deliver ${doc.id} failed: $e');
      }
    } finally {
      _inFlight.remove(doc.id);
    }
  }
}
