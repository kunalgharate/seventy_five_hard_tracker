import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/accountability_partner.dart';
import '../models/partner_review.dart';

/// Firestore collections used by this service.
///
///  partnerships/{partnershipId}   — partnership documents
///  partner_reviews/{reviewId}     — review documents
///  public_progress/{uid}          — sanitised daily progress visible to partners
///  invite_codes/{code}            — lookup table: code → ownerUid + partnershipId
class AccountabilityService {
  static final AccountabilityService _instance =
      AccountabilityService._internal();
  factory AccountabilityService() => _instance;
  AccountabilityService._internal();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool get _isReady {
    try {
      Firebase.app();
      return _auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  String? get currentUid => _auth.currentUser?.uid;

  // ── Invite code generation ───────────────────────────────────────

  /// Generates a random 6-character alphanumeric invite code.
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Partner management ───────────────────────────────────────────

  /// Creates a new partnership and stores an invite code in Firestore.
  /// Returns the created [AccountabilityPartner] or null on failure.
  Future<AccountabilityPartner?> invitePartner({
    required String partnerName,
    String? partnerEmail,
    required PartnerRole role,
  }) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      final code = _generateCode();
      final docRef = _db.collection('partnerships').doc();
      final now = DateTime.now();

      final partner = AccountabilityPartner(
        id: docRef.id,
        ownerUid: uid,
        partnerName: partnerName,
        partnerEmail: partnerEmail,
        role: role,
        status: PartnershipStatus.pending,
        inviteCode: code,
        createdAt: now,
      );

      final batch = _db.batch();

      // Store the partnership
      batch.set(docRef, {
        ...partner.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Store the invite code lookup
      batch.set(_db.collection('invite_codes').doc(code), {
        'ownerUid': uid,
        'partnershipId': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return partner;
    } catch (e) {
      if (kDebugMode) debugPrint('[AccountabilityService] invitePartner: $e');
      return null;
    }
  }

  /// Accepts an invite using a code. Links the current user as the partner.
  /// Returns the updated [AccountabilityPartner] or null on failure.
  Future<AccountabilityPartner?> acceptInvite(String code) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      final codeDoc =
          await _db.collection('invite_codes').doc(code.toUpperCase()).get();

      if (!codeDoc.exists) return null;

      final partnershipId = codeDoc.data()!['partnershipId'] as String;
      final partnershipRef = _db.collection('partnerships').doc(partnershipId);
      final partnershipDoc = await partnershipRef.get();

      if (!partnershipDoc.exists) return null;

      final existing = AccountabilityPartner.fromJson(partnershipDoc.data()!);

      // Prevent accepting your own invite
      if (existing.ownerUid == uid) return null;
      if (existing.status != PartnershipStatus.pending) return null;

      final updated = existing.copyWith(
        partnerUid: uid,
        status: PartnershipStatus.accepted,
        acceptedAt: DateTime.now(),
      );

      await partnershipRef.update({
        'partnerUid': uid,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      return updated;
    } catch (e) {
      if (kDebugMode) debugPrint('[AccountabilityService] acceptInvite: $e');
      return null;
    }
  }

  /// Removes a partnership (both sides).
  Future<bool> removePartner(String partnershipId) async {
    if (!_isReady) return false;
    try {
      await _db.collection('partnerships').doc(partnershipId).delete();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AccountabilityService] removePartner: $e');
      return false;
    }
  }

  /// Fetches all partnerships where the current user is owner OR partner.
  Future<List<AccountabilityPartner>> fetchMyPartnerships() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;

      // Partnerships where I am the owner
      final ownerQuery = await _db
          .collection('partnerships')
          .where('ownerUid', isEqualTo: uid)
          .get();

      // Partnerships where I am the partner
      final partnerQuery = await _db
          .collection('partnerships')
          .where('partnerUid', isEqualTo: uid)
          .get();

      final docs = {...ownerQuery.docs, ...partnerQuery.docs};
      return docs.map((d) => AccountabilityPartner.fromJson(d.data())).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchMyPartnerships: $e');
      }
      return [];
    }
  }

  // ── Progress sharing ─────────────────────────────────────────────

  /// Publishes a sanitised daily progress snapshot so partners can see it.
  Future<void> publishDailyProgress({
    required String dateKey,
    required int completedTasks,
    required int totalTasks,
    required bool dayCompleted,
    required int currentDay,
  }) async {
    if (!_isReady) return;
    try {
      final uid = currentUid!;
      await _db
          .collection('public_progress')
          .doc(uid)
          .collection('days')
          .doc(dateKey)
          .set({
        'dateKey': dateKey,
        'completedTasks': completedTasks,
        'totalTasks': totalTasks,
        'dayCompleted': dayCompleted,
        'currentDay': currentDay,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] publishDailyProgress: $e');
      }
    }
  }

  /// Fetches the public progress for a given user UID (used by partners).
  Future<Map<String, dynamic>?> fetchPartnerProgress(
      String partnerUid, String dateKey) async {
    if (!_isReady) return null;
    try {
      final doc = await _db
          .collection('public_progress')
          .doc(partnerUid)
          .collection('days')
          .doc(dateKey)
          .get();
      return doc.data();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchPartnerProgress: $e');
      }
      return null;
    }
  }

  /// Fetches the last 7 days of public progress for a partner.
  Future<List<Map<String, dynamic>>> fetchPartnerWeeklyProgress(
      String partnerUid) async {
    if (!_isReady) return [];
    try {
      final snapshot = await _db
          .collection('public_progress')
          .doc(partnerUid)
          .collection('days')
          .orderBy('dateKey', descending: true)
          .limit(7)
          .get();
      return snapshot.docs.map((d) => d.data()).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchPartnerWeeklyProgress: $e');
      }
      return [];
    }
  }

  // ── Reviews ──────────────────────────────────────────────────────

  /// Submits a review for a specific day.
  Future<PartnerReview?> submitReview({
    required String subjectUid,
    required String reviewerName,
    required String dateKey,
    required ReviewDecision decision,
    String? comment,
  }) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      final docRef = _db.collection('partner_reviews').doc();
      final now = DateTime.now();

      final review = PartnerReview(
        id: docRef.id,
        subjectUid: subjectUid,
        reviewerUid: uid,
        reviewerName: reviewerName,
        dateKey: dateKey,
        decision: decision,
        comment: comment,
        createdAt: now,
      );

      await docRef.set({
        ...review.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return review;
    } catch (e) {
      if (kDebugMode) debugPrint('[AccountabilityService] submitReview: $e');
      return null;
    }
  }

  /// Fetches all reviews for the current user (reviews of MY progress).
  Future<List<PartnerReview>> fetchMyReviews({int limit = 30}) async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final snapshot = await _db
          .collection('partner_reviews')
          .where('subjectUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((d) => PartnerReview.fromJson(d.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AccountabilityService] fetchMyReviews: $e');
      return [];
    }
  }

  /// Fetches reviews that I (as a partner) need to submit for a given user.
  Future<List<Map<String, dynamic>>> fetchPendingReviewsForPartner(
      String subjectUid) async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;

      // Get the last 7 days of their progress
      final progress = await fetchPartnerWeeklyProgress(subjectUid);

      // Get reviews I've already submitted for this person
      final reviewedSnapshot = await _db
          .collection('partner_reviews')
          .where('subjectUid', isEqualTo: subjectUid)
          .where('reviewerUid', isEqualTo: uid)
          .get();

      final reviewedDates = reviewedSnapshot.docs
          .map((d) => d.data()['dateKey'] as String)
          .toSet();

      // Return days that have progress but no review yet
      return progress
          .where((p) => !reviewedDates.contains(p['dateKey'] as String?))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchPendingReviewsForPartner: $e');
      }
      return [];
    }
  }

  // ── Real-time streams ────────────────────────────────────────────

  /// Stream of partnerships for the current user (real-time updates).
  Stream<List<AccountabilityPartner>> partnershipsStream() {
    if (!_isReady) return const Stream.empty();
    final uid = currentUid!;
    return _db
        .collection('partnerships')
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AccountabilityPartner.fromJson(d.data()))
            .toList());
  }

  /// Stream of reviews for the current user (real-time updates).
  Stream<List<PartnerReview>> reviewsStream() {
    if (!_isReady) return const Stream.empty();
    final uid = currentUid!;
    return _db
        .collection('partner_reviews')
        .where('subjectUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PartnerReview.fromJson(d.data())).toList());
  }
}
