import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Client-side service that detects and expires overdue partner reviews.
///
/// Since Cloud Functions are unavailable, expiry runs on the client:
/// 1. On app open: query all pendingReview tasks past expiresAt → guarded update per task
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
  /// Writes are queued by Firestore while offline. Security Rules re-check
  /// status and expiry against server state, so a concurrent decision is never
  /// overwritten and the expiry still applies when connectivity returns.
  Future<List<String>> checkAndExpireTasks() async {
    if (!_isReady) return [];

    try {
      final now = DateTime.now();
      final uid = _uid!;

      // Find tasks where I'm the accountable user that are overdue
      final snap = await _db
          .collection('accountability_tasks')
          .where('status', isEqualTo: 'pendingReview')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .where('accountableUid', isEqualTo: uid)
          .get();

      if (snap.docs.isEmpty) return [];

      final writes = <Future<void>>[];
      for (final doc in snap.docs) {
        writes.add(doc.reference.update({
          'status': 'expired',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewDecision': 'expired',
        }));
      }
      await Future.wait(writes);
      final expiredIds = snap.docs.map((doc) => doc.id).toList();

      if (kDebugMode && expiredIds.isNotEmpty) {
        debugPrint('[ReviewExpiry] Expired ${expiredIds.length} overdue tasks');
      }

      return expiredIds;
    } catch (e) {
      // Missing composite index (failed-precondition) or rules rejections
      // (permission-denied) are setup problems, not "nothing to expire" —
      // surface them instead of the empty-list fallback.
      if (e is FirebaseException &&
          (e.code == 'failed-precondition' || e.code == 'permission-denied')) {
        rethrow;
      }
      if (kDebugMode) {
        debugPrint('[ReviewExpiry] Check failed: $e');
      }
      return [];
    }
  }

  /// Timer callbacks are fire-and-forget; absorb/log failures so a transient
  /// connectivity or rules error cannot become an uncaught async exception.
  Future<void> _checkAndExpireTasksSafely() async {
    try {
      await checkAndExpireTasks();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReviewExpiry] Background check failed: $e');
      }
    }
  }

  /// Starts a periodic timer (every 5 minutes) to check for expired reviews.
  /// Call this on app start after user is signed in.
  void startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_checkAndExpireTasksSafely()),
    );
    // Also check immediately on start
    unawaited(_checkAndExpireTasksSafely());
  }

  /// Schedules a precise timer for a specific task's expiry time.
  /// When it fires, runs checkAndExpireTasks to catch it (and any others).
  void scheduleNextExpiry(DateTime expiresAt) {
    final delay = expiresAt.difference(DateTime.now());
    if (delay.isNegative) {
      // Already expired — check immediately
      unawaited(_checkAndExpireTasksSafely());
      return;
    }
    _preciseTimer?.cancel();
    _preciseTimer = Timer(delay + const Duration(seconds: 1), () {
      unawaited(_checkAndExpireTasksSafely());
    });
  }

  /// Cancels only the per-task precise timer. The periodic health-check timer
  /// is left running because the singleton outlives individual BLoC instances.
  void cancelPreciseTimer() {
    _preciseTimer?.cancel();
    _preciseTimer = null;
  }

  /// Stops all timers. Call on sign-out or app dispose.
  void dispose() {
    _periodicTimer?.cancel();
    _preciseTimer?.cancel();
    _periodicTimer = null;
    _preciseTimer = null;
  }
}
