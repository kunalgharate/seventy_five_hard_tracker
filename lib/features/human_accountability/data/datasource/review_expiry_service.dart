import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Client-side service that detects and expires overdue partner reviews.
///
/// Since Cloud Functions are unavailable, expiry runs on the client:
/// 1. On app open: query all pendingReview tasks past expiresAt → batch-update to expired
/// 2. Periodic timer: every 5 minutes while app is foregrounded
/// 3. Precise timer: scheduled for the exact expiresAt of a newly submitted task
class ReviewExpiryService {
  static final ReviewExpiryService _instance = ReviewExpiryService._();
  factory ReviewExpiryService() => _instance;
  ReviewExpiryService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Timer? _periodicTimer;
  Timer? _preciseTimer;

  bool get _isReady => _auth.currentUser != null;
  String? get _uid => _auth.currentUser?.uid;

  /// Queries Firestore for tasks in pendingReview status where expiresAt < now.
  /// Batch-updates them to expired. Returns the list of expired task IDs.
  Future<List<String>> checkAndExpireTasks() async {
    if (!_isReady) return [];

    try {
      final now = DateTime.now();
      final uid = _uid!;

      // Find tasks where I'm the owner or the accountable user that are overdue
      final snap = await _db
          .collection('accountability_tasks')
          .where('status', isEqualTo: 'pendingReview')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .where('accountableUid', isEqualTo: uid)
          .get();

      if (snap.docs.isEmpty) return [];

      final batch = _db.batch();
      final expiredIds = <String>[];

      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'status': 'expired',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewDecision': 'expired',
        });
        expiredIds.add(doc.id);
      }

      await batch.commit();

      if (kDebugMode && expiredIds.isNotEmpty) {
        debugPrint('[ReviewExpiry] Expired ${expiredIds.length} overdue tasks');
      }

      return expiredIds;
    } catch (e) {
      if (kDebugMode) debugPrint('[ReviewExpiry] Check failed: $e');
      return [];
    }
  }

  /// Starts a periodic timer (every 5 minutes) to check for expired reviews.
  /// Call this on app start after user is signed in.
  void startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => checkAndExpireTasks(),
    );
    // Also check immediately on start
    checkAndExpireTasks();
  }

  /// Schedules a precise timer for a specific task's expiry time.
  /// When it fires, runs checkAndExpireTasks to catch it (and any others).
  void scheduleNextExpiry(DateTime expiresAt) {
    final delay = expiresAt.difference(DateTime.now());
    if (delay.isNegative) {
      // Already expired — check immediately
      checkAndExpireTasks();
      return;
    }
    _preciseTimer?.cancel();
    _preciseTimer = Timer(delay + const Duration(seconds: 1), () {
      checkAndExpireTasks();
    });
  }

  /// Stops all timers. Call on sign-out or app dispose.
  void dispose() {
    _periodicTimer?.cancel();
    _preciseTimer?.cancel();
    _periodicTimer = null;
    _preciseTimer = null;
  }
}
