import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Per-category notification preferences, stored on the user's own doc as
/// `notifPrefs` (`users/{uid}` — self-update already allowed by rules).
/// Absent category or doc means enabled (fail-open).
///
/// Enforced client-side by the dispatch listener (and Home cards). If a
/// server push sender is added later, mirror `categoryForType` there.
class NotificationPreferences {
  NotificationPreferences._();
  static final NotificationPreferences instance = NotificationPreferences._();

  static const String keyReviews = 'reviews';
  static const String keyTasks = 'tasks';
  static const String keyInvitations = 'invitations';
  static const String keyMessages = 'messages';

  static const List<String> allKeys = [
    keyReviews,
    keyTasks,
    keyInvitations,
    keyMessages,
  ];

  /// Notification doc `type` (enum name) → preference category.
  /// Unknown types return null → treated as enabled (fail-open).
  static String? categoryForType(String type) {
    switch (type) {
      case 'taskNeedsReview':
      case 'reviewApproved':
      case 'reviewRejected':
      case 'reviewReminder20h':
      case 'reviewExpired':
        return keyReviews;
      case 'taskAssigned':
        return keyTasks;
      case 'invitationReceived':
      case 'invitationAccepted':
      case 'invitationDeclined':
        return keyInvitations;
      case 'partnerMessage':
        return keyMessages;
      default:
        return null;
    }
  }

  /// Loads the raw prefs map (missing entries = enabled). Null when signed
  /// out or on read failure (callers treat null as all-enabled).
  Future<Map<String, bool>?> load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final raw = snap.data()?['notifPrefs'];
      if (raw is! Map) return {};
      return {
        for (final e in raw.entries)
          if (e.key is String && e.value is bool)
            e.key as String: e.value as bool,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[NotifPrefs] load failed: $e');
      return null;
    }
  }

  /// Persists one category toggle (merge — never clobbers sibling fields
  /// like fcmTokens).
  Future<void> setEnabled(String key, bool enabled) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    return FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'notifPrefs': {key: enabled},
      },
      SetOptions(merge: true),
    );
  }

  static bool isEnabledIn(Map<String, bool>? prefs, String type) {
    final category = categoryForType(type);
    if (category == null) return true;
    if (prefs == null) return true;
    return prefs[category] ?? true;
  }

  // ── Cached check for the dispatch listener ─────────────────────────
  Map<String, bool>? _cache;
  DateTime? _cacheAt;
  static const _cacheTtl = Duration(minutes: 5);

  /// Cached, fail-open check used on the per-notification hot path.
  Future<bool> isTypeEnabled(String type) async {
    if (categoryForType(type) == null) return true;
    final now = DateTime.now();
    if (_cache == null ||
        _cacheAt == null ||
        now.difference(_cacheAt!) > _cacheTtl) {
      _cache = await load();
      _cacheAt = now;
    }
    return isEnabledIn(_cache, type);
  }

  /// Drops the cache (called on account switch so the next account never
  /// inherits stale prefs).
  void invalidateCache() {
    _cache = null;
    _cacheAt = null;
  }

  /// Re-reads prefs now so the next delivery honors fresh values without
  /// paying a cold fetch on the notification hot path.
  Future<void> warmCache() async {
    _cache = await load();
    _cacheAt = DateTime.now();
  }
}
