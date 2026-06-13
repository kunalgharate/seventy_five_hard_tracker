import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../../../models/collaborator.dart';
import '../models/accountability_partner.dart';
import '../models/accountability_task.dart';
import '../models/partner_review.dart';
import '../models/app_user.dart';
import '../models/accountability_invitation.dart';

/// Firestore collections:
///   partnerships/{id}              — partnership documents
///   invite_codes/{code}            — code → ownerUid + partnershipId
///   public_progress/{uid}/days/{dateKey} — sanitised daily progress
///   partner_reviews/{id}           — partner feedback
class AccountabilityService {
  static final AccountabilityService _instance =
      AccountabilityService._internal();
  factory AccountabilityService() => _instance;
  AccountabilityService._internal();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // ── Readiness ────────────────────────────────────────────────────

  bool get _isReady {
    try {
      Firebase.app(); // throws if not initialized
      return _auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  String? get currentUid => _auth.currentUser?.uid;

  /// Display name or email of the signed-in user, used as reviewer name.
  String get currentUserDisplayName {
    final user = _auth.currentUser;
    if (user == null) return 'Partner';
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }
    return 'User ${user.uid.substring(0, 6)}';
  }

  // ── Helpers ──────────────────────────────────────────────────────

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Safely parse a Firestore field that may be a Timestamp or ISO string.
  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  /// Parse an [AccountabilityPartner] from a Firestore document snapshot,
  /// handling Timestamp fields correctly.
  AccountabilityPartner _partnerFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccountabilityPartner(
      id: data['id'] as String? ?? doc.id,
      ownerUid: data['ownerUid'] as String,
      partnerUid: data['partnerUid'] as String?,
      partnerName: data['partnerName'] as String,
      partnerEmail: data['partnerEmail'] as String?,
      role:
          PartnerRoleExtension.fromString(data['role'] as String? ?? 'friend'),
      status: PartnershipStatusExtension.fromString(
          data['status'] as String? ?? 'pending'),
      inviteCode: data['inviteCode'] as String? ?? '',
      createdAt: _parseDate(data['createdAt']),
      acceptedAt:
          data['acceptedAt'] != null ? _parseDate(data['acceptedAt']) : null,
    );
  }

  // ── Partner management ───────────────────────────────────────────

  /// Creates a new partnership + invite code in Firestore atomically.
  Future<AccountabilityPartner?> invitePartner({
    required String partnerName,
    String? partnerEmail,
    required PartnerRole role,
  }) async {
    if (!_isReady) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] invitePartner: not ready (Firebase not initialized or user not signed in)');
      }
      return null;
    }
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

      batch.set(docRef, {
        'id': docRef.id,
        'ownerUid': uid,
        'partnerUid': null,
        'partnerName': partnerName,
        'partnerEmail': partnerEmail,
        'role': role.name,
        'status': 'pending',
        'inviteCode': code,
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': null,
      });

      batch.set(_db.collection('invite_codes').doc(code), {
        'ownerUid': uid,
        'partnershipId': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] invitePartner: success, code=$code, docId=${docRef.id}');
      }
      return partner;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] invitePartner error: $e');
      }
      // Rethrow so the bloc surfaces the real reason (e.g. permission-denied)
      // instead of silently returning null and showing a misleading UI state.
      rethrow;
    }
  }

  /// Accepts an invite using a 6-char code.
  ///
  /// Throws a descriptive [Exception] on failure so callers can surface the
  /// exact reason to the user instead of a generic "invalid code" message.
  Future<AccountabilityPartner?> acceptInvite(String code) async {
    if (!_isReady) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] acceptInvite: not ready');
      }
      throw Exception(
          'You must be signed in to accept an invite. Please sign in and try again.');
    }
    try {
      final uid = currentUid!;
      final upperCode = code.trim().toUpperCase();

      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] acceptInvite: looking up code=$upperCode');
      }

      final codeDoc = await _db.collection('invite_codes').doc(upperCode).get();
      if (!codeDoc.exists) {
        if (kDebugMode) {
          debugPrint('[AccountabilityService] acceptInvite: code not found');
        }
        throw Exception(
            'Invite code "$upperCode" not found. Double-check the code and try again.');
      }

      final partnershipId = codeDoc.data()!['partnershipId'] as String;
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] acceptInvite: found partnershipId=$partnershipId');
      }

      final partnershipRef = _db.collection('partnerships').doc(partnershipId);
      final partnershipDoc = await partnershipRef.get();

      if (!partnershipDoc.exists) {
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] acceptInvite: partnership doc not found');
        }
        throw Exception(
            'The partnership linked to this code no longer exists. Ask your partner to create a new invite.');
      }

      final existing = _partnerFromDoc(partnershipDoc);

      if (existing.ownerUid == uid) {
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] acceptInvite: cannot accept own invite');
        }
        throw Exception('You cannot accept your own invite code.');
      }
      if (existing.status != PartnershipStatus.pending) {
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] acceptInvite: already accepted/declined');
        }
        throw Exception(
            'This invite has already been accepted or is no longer valid.');
      }

      await partnershipRef.update({
        'partnerUid': uid,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Clean up the invite code so it can't be reused
      await _db.collection('invite_codes').doc(upperCode).delete();

      final updated = existing.copyWith(
        partnerUid: uid,
        status: PartnershipStatus.accepted,
        acceptedAt: DateTime.now(),
      );

      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] acceptInvite: success, partnershipId=$partnershipId');
      }
      return updated;
    } on Exception {
      rethrow; // already descriptive — let the bloc handle it
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] acceptInvite error: $e');
      }
      // Likely a Firestore permission error — give a helpful hint
      throw Exception(
          'Could not look up the invite code. This is usually a Firestore permissions issue. '
          'Make sure invite_codes allows read by any signed-in user.\n\nDetails: $e');
    }
  }

  /// Rejects/declines an incoming partnership request.
  Future<bool> rejectInvite(String partnershipId) async {
    if (!_isReady) return false;
    try {
      await _db.collection('partnerships').doc(partnershipId).update({
        'status': 'declined',
        'partnerUid': currentUid,
      });
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] rejectInvite: $partnershipId declined');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] rejectInvite error: $e');
      }
      return false;
    }
  }

  /// Fetches incoming partnership requests — where someone invited ME
  /// (current user's UID matches no partnerUid yet and I am NOT the owner).
  /// These are partnerships where ownerUid != myUid and status == pending
  /// and the invite code lookup maps to my email or I entered the code.
  /// Since invite-code flow sets partnerUid on accept, incoming requests
  /// are partnerships where partnerUid == myUid AND status == pending.
  Future<List<AccountabilityPartner>> fetchIncomingRequests() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final snap = await _db
          .collection('partnerships')
          .where('partnerUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();
      return snap.docs.map(_partnerFromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchIncomingRequests error: $e');
      }
      return [];
    }
  }

  /// Removes a partnership.
  Future<bool> removePartner(String partnershipId) async {
    if (!_isReady) return false;
    try {
      await _db.collection('partnerships').doc(partnershipId).delete();
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] removePartner: $partnershipId deleted');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] removePartner error: $e');
      }
      return false;
    }
  }

  /// Fetches all partnerships where the current user is owner OR partner.
  Future<List<AccountabilityPartner>> fetchMyPartnerships() async {
    if (!_isReady) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchMyPartnerships: not ready');
      }
      return [];
    }
    try {
      final uid = currentUid!;
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchMyPartnerships: uid=$uid');
      }

      final ownerQuery = await _db
          .collection('partnerships')
          .where('ownerUid', isEqualTo: uid)
          .get();

      final partnerQuery = await _db
          .collection('partnerships')
          .where('partnerUid', isEqualTo: uid)
          .get();

      // Merge and deduplicate by doc ID
      final seen = <String>{};
      final results = <AccountabilityPartner>[];
      for (final doc in [...ownerQuery.docs, ...partnerQuery.docs]) {
        if (seen.add(doc.id)) {
          results.add(_partnerFromDoc(doc));
        }
      }
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchMyPartnerships: found ${results.length}');
      }
      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchMyPartnerships error: $e');
      }
      return [];
    }
  }

  /// Finds an accepted partnership between the current user and [otherUid].
  /// Returns the partnership if found and accepted, otherwise null.
  Future<AccountabilityPartner?> findAcceptedPartnership(String otherUid) async {
    if (!_isReady) return null;
    try {
      final myUid = currentUid!;
      // Query where I'm the owner and they're the partner
      final q1 = await _db
          .collection('partnerships')
          .where('ownerUid', isEqualTo: myUid)
          .where('partnerUid', isEqualTo: otherUid)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) return _partnerFromDoc(q1.docs.first);

      // Query where they're the owner and I'm the partner
      final q2 = await _db
          .collection('partnerships')
          .where('ownerUid', isEqualTo: otherUid)
          .where('partnerUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) return _partnerFromDoc(q2.docs.first);

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] findAcceptedPartnership error: $e');
      }
      return null;
    }
  }

  /// Ensure an accepted partnership exists with [otherUid].
  /// Creates one if none is found. Returns the partnership ID or null.
  Future<String?> ensurePartnership(String otherUid, String otherName) async {
    if (!_isReady) return null;
    try {
      final existing = await findAcceptedPartnership(otherUid);
      if (existing != null) {
        if (kDebugMode) {
          debugPrint('[AccountabilityService] ensurePartnership: existing partnership ${existing.id}');
        }
        return existing.id;
      }

      final myUid = currentUid!;
      final code = _generateCode();
      final docRef = _db.collection('partnerships').doc();
      final now = DateTime.now();

      if (kDebugMode) {
        debugPrint('[AccountabilityService] ensurePartnership: creating new partnership with $otherUid ($otherName)');
      }

      await docRef.set({
        'id': docRef.id,
        'ownerUid': myUid,
        'partnerUid': otherUid,
        'partnerName': otherName,
        'role': PartnerRole.friend.name,
        'status': 'accepted',
        'inviteCode': code,
        'createdAt': now.toIso8601String(),
        'acceptedAt': now.toIso8601String(),
      });

      if (kDebugMode) {
        debugPrint('[AccountabilityService] ensurePartnership: created ${docRef.id}');
      }
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] ensurePartnership error: $e');
      }
      return null;
    }
  }

  // ── Progress sharing ─────────────────────────────────────────────

  Future<void> publishDailyProgress({
    required String dateKey,
    required int completedTasks,
    required int totalTasks,
    required bool dayCompleted,
    required int currentDay,
    List<Map<String, dynamic>>? taskDetails, // [{name, completed, type}]
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
        'taskDetails': taskDetails ?? [],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) {
        debugPrint('[AccountabilityService] publishDailyProgress: $dateKey');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] publishDailyProgress error: $e');
      }
    }
  }

  /// Publish a snapshot of the user's current challenge names so partners
  /// can display them even when no task toggle has happened today.
  Future<void> publishChallengeMeta({
    required List<String> challengeNames,
    required int currentDay,
  }) async {
    if (!_isReady) return;
    try {
      final uid = currentUid!;
      await _db.collection('public_progress').doc(uid).set({
        'challengeNames': challengeNames,
        'currentDay': currentDay,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] publishChallengeMeta error: $e');
      }
    }
  }

  /// Fetch the challenge names for a partner.
  Future<List<String>> fetchPartnerChallengeNames(String partnerUid) async {
    if (!_isReady) return [];
    try {
      final doc = await _db.collection('public_progress').doc(partnerUid).get();
      final names = doc.data()?['challengeNames'] as List?;
      return names?.cast<String>() ?? [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchPartnerChallengeNames error: $e');
      }
      return [];
    }
  }

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
        debugPrint('[AccountabilityService] fetchPartnerProgress error: $e');
      }
      return null;
    }
  }

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
        debugPrint(
            '[AccountabilityService] fetchPartnerWeeklyProgress error: $e');
      }
      return [];
    }
  }

  // ── Reviews ──────────────────────────────────────────────────────

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

      final review = PartnerReview(
        id: docRef.id,
        subjectUid: subjectUid,
        reviewerUid: uid,
        reviewerName: reviewerName,
        dateKey: dateKey,
        decision: decision,
        comment: comment,
        createdAt: DateTime.now(),
      );

      await docRef.set({
        'id': docRef.id,
        'subjectUid': subjectUid,
        'reviewerUid': uid,
        'reviewerName': reviewerName,
        'dateKey': dateKey,
        'decision': decision.name,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] submitReview: $dateKey for $subjectUid');
      }
      return review;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] submitReview error: $e');
      }
      return null;
    }
  }

  Future<List<PartnerReview>> fetchMyReviews({int limit = 30}) async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      // No orderBy — avoids requiring a composite Firestore index.
      // Sort client-side instead.
      final snapshot = await _db
          .collection('partner_reviews')
          .where('subjectUid', isEqualTo: uid)
          .limit(limit)
          .get();

      final reviews = snapshot.docs.map((d) {
        final data = d.data();
        return PartnerReview(
          id: data['id'] as String? ?? d.id,
          subjectUid: data['subjectUid'] as String,
          reviewerUid: data['reviewerUid'] as String,
          reviewerName: data['reviewerName'] as String? ?? 'Partner',
          dateKey: data['dateKey'] as String,
          decision: ReviewDecisionExtension.fromString(
              data['decision'] as String? ?? 'pending'),
          comment: data['comment'] as String?,
          createdAt: _parseDate(data['createdAt']),
        );
      }).toList();
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchMyReviews error: $e');
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchPendingReviewsForPartner(
      String subjectUid) async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final progress = await fetchPartnerWeeklyProgress(subjectUid);

      final reviewedSnapshot = await _db
          .collection('partner_reviews')
          .where('subjectUid', isEqualTo: subjectUid)
          .where('reviewerUid', isEqualTo: uid)
          .get();

      final reviewedDates = reviewedSnapshot.docs
          .map((d) => d.data()['dateKey'] as String)
          .toSet();

      return progress
          .where((p) => !reviewedDates.contains(p['dateKey'] as String?))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchPendingReviewsForPartner error: $e');
      }
      return [];
    }
  }

  // ── Real-time streams ────────────────────────────────────────────

  /// Stream of ALL partnerships for the current user (owner + partner side).
  Stream<List<AccountabilityPartner>> partnershipsStream() {
    if (!_isReady) return const Stream.empty();
    final uid = currentUid!;
    // Stream owner-side partnerships; partner-side requires a separate stream
    // or a composite. We use the owner query as the primary stream.
    return _db
        .collection('partnerships')
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map(_partnerFromDoc).toList());
  }

  /// Stream of reviews for the current user.
  Stream<List<PartnerReview>> reviewsStream() {
    if (!_isReady) return const Stream.empty();
    final uid = currentUid!;
    return _db
        .collection('partner_reviews')
        .where('subjectUid', isEqualTo: uid)
        .limit(20)
        .snapshots()
        .map((snap) {
      final reviews = snap.docs.map((d) {
        final data = d.data();
        return PartnerReview(
          id: data['id'] as String? ?? d.id,
          subjectUid: data['subjectUid'] as String,
          reviewerUid: data['reviewerUid'] as String,
          reviewerName: data['reviewerName'] as String? ?? 'Partner',
          dateKey: data['dateKey'] as String,
          decision: ReviewDecisionExtension.fromString(
              data['decision'] as String? ?? 'pending'),
          comment: data['comment'] as String?,
          createdAt: _parseDate(data['createdAt']),
        );
      }).toList();
      // Sort client-side — no composite index needed
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    });
  }

  // ── Accountability Tasks ─────────────────────────────────────────

  /// Creates a task request. Status starts as [AccountabilityTaskStatus.requested].
  /// The partner must accept before it becomes active (pending).
  Future<AccountabilityTask?> createAccountabilityTask({
    required String accountableUid,
    required String accountableName,
    String partnershipId = '',
    required String title,
    String? description,
    DateTime? dueDate,
    String? challengeId,
  }) async {
    if (!_isReady) return null;
    try {
      final ref = _db.collection('accountability_tasks').doc();
      final task = AccountabilityTask(
        id: ref.id,
        assignedByUid: currentUid!,
        assignedByName: currentUserDisplayName,
        accountableUid: accountableUid,
        accountableName: accountableName,
        partnershipId: partnershipId,
        challengeId: challengeId,
        title: title,
        description: description,
        status: AccountabilityTaskStatus.requested,
        dueDate: dueDate,
        assignedAt: DateTime.now(),
      );
      await ref.set(task.toFirestore());
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] createTask: ${ref.id} for $accountableUid challengeId=$challengeId partnershipId=$partnershipId');
      }
      return task;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] createTask error: $e');
      }
      return null;
    }
  }

  /// Returns Map<challengeId, accountableUid> for tasks the current user assigned
  /// that are active (pending or requested). Used to show lock icons on daily cards.
  Future<Map<String, String>> fetchAssignedChallengeMap() async {
    if (!_isReady) return {};
    try {
      final snap = await _db
          .collection('accountability_tasks')
          .where('assignedByUid', isEqualTo: currentUid!)
          .get();
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final cid = data['challengeId'] as String?;
        final aUid = data['accountableUid'] as String?;
        final status = data['status'] as String? ?? '';
        if (cid != null &&
            aUid != null &&
            (status == 'pending' || status == 'requested')) {
          map[cid] = aUid;
        }
      }
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchAssignedChallengeMap: ${map.length} entries');
      }
      return map;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchAssignedChallengeMap error: $e');
      }
      return {};
    }
  }

  /// Returns Map<challengeId, assignerName> for tasks assigned TO the current user.
  /// Used to show the assigner's name on the accountable person's task cards.
  Future<Map<String, String>> fetchAccountableForMap() async {
    if (!_isReady) return {};
    try {
      final snap = await _db
          .collection('accountability_tasks')
          .where('accountableUid', isEqualTo: currentUid!)
          .get();
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final cid = data['challengeId'] as String?;
        final assignerName = data['assignedByName'] as String?;
        final status = data['status'] as String? ?? '';
        // Only show partner chip after the task has been accepted (pending/completed)
        if (cid != null &&
            assignerName != null &&
            (status == 'pending' || status == 'completed')) {
          map[cid] = assignerName;
        }
      }
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchAccountableForMap: ${map.length} entries');
      }
      return map;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchAccountableForMap error: $e');
      }
      return {};
    }
  }

  /// Returns tasks assigned TO the current user that are active (pending status).
  /// Used to show partner-assigned tasks on the daily tasks screen.
  Future<List<AccountabilityTask>> fetchTasksAssignedToMe() async {
    if (!_isReady) return [];
    try {
      final snap = await _db
          .collection('accountability_tasks')
          .where('accountableUid', isEqualTo: currentUid!)
          .get();
      final tasks = snap.docs
          .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
          .where((t) =>
              t.status == AccountabilityTaskStatus.requested ||
              t.status == AccountabilityTaskStatus.pending)
          .toList();
      tasks.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchTasksAssignedToMe: ${tasks.length}');
      }
      return tasks;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchTasksAssignedToMe error: $e');
      }
      return [];
    }
  }

  /// Fetches incoming task requests for the current user
  /// (tasks where accountableUid == myUid && status is requested or pending).
  Future<List<AccountabilityTask>> fetchIncomingTaskRequests() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final snap = await _db
          .collection('accountability_tasks')
          .where('accountableUid', isEqualTo: uid)
          .get();
      final tasks = snap.docs
          .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
          .where((t) => t.status == AccountabilityTaskStatus.requested)
          .toList();
      tasks.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchIncomingTaskRequests: ${tasks.length}');
      }
      return tasks;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchIncomingTaskRequests error: $e');
      }
      return [];
    }
  }

  /// Accept a task request — sets status to pending.
  /// Only the accountable user can accept.
  Future<bool> acceptTaskRequest(String taskId) async {
    if (!_isReady) return false;
    try {
      final ref = _db.collection('accountability_tasks').doc(taskId);
      final doc = await ref.get();
      if (!doc.exists) return false;
      if (doc.data()!['accountableUid'] != currentUid) return false;
      await ref.update({'status': AccountabilityTaskStatus.pending.name});
      if (kDebugMode) {
        debugPrint('[AccountabilityService] acceptTaskRequest: $taskId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] acceptTaskRequest error: $e');
      }
      return false;
    }
  }

  /// Decline a task request — sets status to declined.
  /// Only the accountable user can decline.
  Future<bool> declineTaskRequest(String taskId) async {
    if (!_isReady) return false;
    try {
      final ref = _db.collection('accountability_tasks').doc(taskId);
      final doc = await ref.get();
      if (!doc.exists) return false;
      if (doc.data()!['accountableUid'] != currentUid) return false;
      await ref.update({'status': AccountabilityTaskStatus.declined.name});
      if (kDebugMode) {
        debugPrint('[AccountabilityService] declineTaskRequest: $taskId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] declineTaskRequest error: $e');
      }
      return false;
    }
  }

  /// Mark a task as completed — only allowed if current user == accountableUid.
  Future<bool> completeAccountabilityTask(String taskId) async {
    if (!_isReady) return false;
    try {
      final ref = _db.collection('accountability_tasks').doc(taskId);
      final doc = await ref.get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      // Security check: only the accountable person can complete
      if (data['accountableUid'] != currentUid) {
        if (kDebugMode) {
          debugPrint('[AccountabilityService] completeTask: not authorized');
        }
        return false;
      }

      await ref.update({
        'status': AccountabilityTaskStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] completeTask error: $e');
      }
      return false;
    }
  }

  /// Unmark a completed task back to pending — only allowed if current user == accountableUid.
  Future<bool> uncompleteAccountabilityTask(String taskId) async {
    if (!_isReady) return false;
    try {
      final ref = _db.collection('accountability_tasks').doc(taskId);
      final doc = await ref.get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      // Security check: only the accountable person can uncomplete
      if (data['accountableUid'] != currentUid) {
        if (kDebugMode) {
          debugPrint('[AccountabilityService] uncompleteTask: not authorized');
        }
        return false;
      }

      await ref.update({
        'status': AccountabilityTaskStatus.pending.name,
        'completedAt': null,
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] uncompleteTask error: $e');
      }
      return false;
    }
  }

  /// Fetch all tasks for a partnership.
  /// Fetch all tasks for a partnership.
  /// Queries by partnershipId — the primary and only filter needed.
  Future<List<AccountabilityTask>> fetchTasksForPartnership(
      String partnershipId) async {
    if (!_isReady) return [];
    try {
      final myUid = currentUid!;
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchTasksForPartnership: partnershipId=$partnershipId myUid=$myUid');
      }

      // Step 1: get the partnership doc to resolve the other person's UID
      final partnershipDoc =
          await _db.collection('partnerships').doc(partnershipId).get();

      String? otherUid;
      if (partnershipDoc.exists) {
        final data = partnershipDoc.data()!;
        final ownerUid = data['ownerUid'] as String?;
        final partnerUid = data['partnerUid'] as String?;
        otherUid = (ownerUid == myUid) ? partnerUid : ownerUid;
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] partnership owner=$ownerUid partner=$partnerUid otherUid=$otherUid');
        }
      }

      // Step 2: run parallel queries
      final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

      // Q1: exact partnershipId match
      futures.add(_db
          .collection('accountability_tasks')
          .where('partnershipId', isEqualTo: partnershipId)
          .get());

      if (otherUid != null) {
        // Q2: tasks I assigned to the other person (catches partnershipId mismatch)
        futures.add(_db
            .collection('accountability_tasks')
            .where('assignedByUid', isEqualTo: myUid)
            .where('accountableUid', isEqualTo: otherUid)
            .get());

        // Q3: tasks the other person assigned to me
        futures.add(_db
            .collection('accountability_tasks')
            .where('assignedByUid', isEqualTo: otherUid)
            .where('accountableUid', isEqualTo: myUid)
            .get());
      }

      final results = await Future.wait(futures);

      final seen = <String>{};
      final all = <AccountabilityTask>[];
      for (final snap in results) {
        for (final doc in snap.docs) {
          if (seen.add(doc.id)) {
            all.add(AccountabilityTask.fromFirestore(doc.data(), id: doc.id));
          }
        }
      }

      // Deduplicate by title+accountableUid — catches duplicate docs
      // created due to previous bugs
      final deduped = <String, AccountabilityTask>{};
      for (final t in all) {
        final key = '${t.title.toLowerCase().trim()}|${t.accountableUid}';
        // Keep the most recently assigned one
        if (!deduped.containsKey(key) ||
            t.assignedAt.isAfter(deduped[key]!.assignedAt)) {
          deduped[key] = t;
        }
      }
      final allDeduped = deduped.values.toList();

      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchTasksForPartnership: found ${allDeduped.length} total');
        for (final t in allDeduped) {
          debugPrint(
              '  [${t.status.name}] "${t.title}" assignedBy=${t.assignedByUid} accountable=${t.accountableUid}');
        }
      }

      final tasks = allDeduped.where((t) {
        if (t.status == AccountabilityTaskStatus.pending ||
            t.status == AccountabilityTaskStatus.completed) {
          return true;
        }
        // Show requested tasks the current user assigned (waiting for partner to accept)
        if (t.status == AccountabilityTaskStatus.requested &&
            t.assignedByUid == myUid) {
          return true;
        }
        return false;
      }).toList();

      tasks.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchTasksForPartnership: ${tasks.length} active');
      }
      return tasks;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchTasks error: $e');
      }
      return [];
    }
  }

  /// Real-time stream of tasks for a partnership.
  Stream<List<AccountabilityTask>> tasksStream(String partnershipId) {
    if (!_isReady) return const Stream.empty();
    return _db
        .collection('accountability_tasks')
        .where('partnershipId', isEqualTo: partnershipId)
        .snapshots()
        .map((snap) {
      final tasks = snap.docs
          .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
          .toList();
      tasks.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
      return tasks;
    });
  }

  // ── Phase 1: Users collection ────────────────────────────────────────────

  /// Registers (or updates) the current user in the `users` collection.
  /// Called on every successful sign-in so the record stays fresh.
  /// Safe to call even if the collection doesn't exist yet — Firestore
  /// creates it on the first write.
  Future<void> registerUser() async {
    if (!_isReady) return;
    try {
      final user = _auth.currentUser!;
      final displayName = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : (user.email?.split('@').first ?? 'User');

      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': displayName,
        'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
        // Only set createdAt if the doc doesn't already exist
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('[AccountabilityService] registerUser: ${user.uid}');
      }
    } catch (e) {
      // Non-fatal — don't break sign-in if this fails
      if (kDebugMode) {
        debugPrint('[AccountabilityService] registerUser error: $e');
      }
    }
  }

  /// Looks up a registered user by email address.
  /// Returns null if no user with that email has signed in yet.
  Future<AppUser?> findUserByEmail(String email) async {
    if (!_isReady) return null;
    try {
      final trimmed = email.trim().toLowerCase();
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: trimmed)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return AppUser.fromFirestore(snap.docs.first.data());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] findUserByEmail error: $e');
      }
      return null;
    }
  }

  // ── Phase 2: Email-based invitations ────────────────────────────────────────

  /// Sends an email-based collaborator invitation.
  ///
  /// 1. Looks up `toEmail` in the `users` collection.
  /// 2. Pre-creates a `partnerships` doc (status: pending) — same shape as
  ///    the existing code-based flow so the rest of the app works unchanged.
  /// 3. Creates an `invitations` doc that links to the partnership.
  ///
  /// Returns the created [AccountabilityInvitation] or throws on failure.
  Future<AccountabilityInvitation> sendEmailInvite({
    required String toEmail,
    required PartnerRole role,
  }) async {
    if (!_isReady) {
      throw Exception('You must be signed in to send an invitation.');
    }

    final uid = currentUid!;
    final user = _auth.currentUser!;
    final senderEmail = (user.email ?? '').toLowerCase();
    final senderName = currentUserDisplayName;
    final recipientEmail = toEmail.trim().toLowerCase();

    if (recipientEmail == senderEmail) {
      throw Exception('You cannot invite yourself.');
    }

    // Look up recipient in users collection (may be null)
    final recipient = await findUserByEmail(recipientEmail);

    // Pre-create the partnership doc (same structure as existing invitePartner)
    final partnershipRef = _db.collection('partnerships').doc();
    final inviteRef = _db.collection('invitations').doc();
    final now = DateTime.now();

    final partnerName =
        recipient?.displayName ?? recipientEmail.split('@').first;

    final batch = _db.batch();

    // Partnership doc — identical shape to existing code-based flow
    batch.set(partnershipRef, {
      'id': partnershipRef.id,
      'ownerUid': uid,
      'partnerUid': recipient?.uid, // null if not yet registered
      'partnerName': partnerName,
      'partnerEmail': recipientEmail,
      'role': role.name,
      'status': 'pending',
      'inviteCode': '', // empty — not code-based
      'inviteType': 'email', // distinguishes from code-based invites
      'createdAt': FieldValue.serverTimestamp(),
      'acceptedAt': null,
    });

    // Invitation doc
    final invitation = AccountabilityInvitation(
      id: inviteRef.id,
      fromUid: uid,
      fromName: senderName,
      fromEmail: senderEmail,
      toEmail: recipientEmail,
      toUid: recipient?.uid,
      partnershipId: partnershipRef.id,
      role: role,
      status: InvitationStatus.pending,
      createdAt: now,
    );

    batch.set(inviteRef, invitation.toFirestore());

    await batch.commit();

    if (kDebugMode) {
      debugPrint(
          '[AccountabilityService] sendEmailInvite: sent to $recipientEmail '
          'partnershipId=${partnershipRef.id} inviteId=${inviteRef.id}');
    }

    return invitation.copyWith(id: inviteRef.id);
  }

  /// Fetches invitations received by the current user (by email).
  /// Also includes invitations where [toUid] == currentUid for robustness.
  Future<List<AccountabilityInvitation>> fetchMyInvitations() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final email = (_auth.currentUser?.email ?? '').toLowerCase();

      // Single-field queries — filter status client-side to avoid composite index.
      final emailQuery = email.isNotEmpty
          ? _db
              .collection('invitations')
              .where('toEmail', isEqualTo: email)
              .get()
          : Future.value(null);

      final uidQuery =
          _db.collection('invitations').where('toUid', isEqualTo: uid).get();

      final results = await Future.wait([emailQuery, uidQuery]);

      final seen = <String>{};
      final invitations = <AccountabilityInvitation>[];

      for (final snap in results) {
        if (snap == null) continue;
        for (final doc in (snap as QuerySnapshot).docs) {
          if (seen.add(doc.id)) {
            final inv = AccountabilityInvitation.fromFirestore(
              doc.data() as Map<String, dynamic>,
              id: doc.id,
            );
            // Client-side filter: only pending
            if (inv.status == InvitationStatus.pending) {
              invitations.add(inv);
            }
          }
        }
      }

      invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return invitations;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchMyInvitations error: $e');
      }
      return [];
    }
  }

  /// Fetches invitations *sent* by the current user (for Pending Invites section).
  Future<List<AccountabilityInvitation>> fetchSentInvitations() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      // Single-field query + client-side status filter
      final snap = await _db
          .collection('invitations')
          .where('fromUid', isEqualTo: uid)
          .get();

      final invitations = snap.docs
          .map(
              (d) => AccountabilityInvitation.fromFirestore(d.data(), id: d.id))
          .where((inv) => inv.status == InvitationStatus.pending)
          .toList();
      invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return invitations;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchSentInvitations error: $e');
      }
      return [];
    }
  }

  /// Accepts an email-based invitation.
  ///
  /// Updates both the `invitations` doc and the linked `partnerships` doc.
  /// Returns the updated [AccountabilityPartner] on success.
  Future<AccountabilityPartner?> acceptEmailInvite(String invitationId) async {
    if (!_isReady) {
      throw Exception('You must be signed in to accept an invitation.');
    }
    try {
      final uid = currentUid!;
      final inviteRef = _db.collection('invitations').doc(invitationId);
      final inviteDoc = await inviteRef.get();

      if (!inviteDoc.exists) {
        throw Exception('Invitation not found or already processed.');
      }

      final invitation = AccountabilityInvitation.fromFirestore(
        inviteDoc.data()!,
        id: invitationId,
      );

      if (invitation.status != InvitationStatus.pending) {
        throw Exception('This invitation has already been responded to.');
      }

      if (invitation.fromUid == uid) {
        throw Exception('You cannot accept your own invitation.');
      }

      final partnershipRef =
          _db.collection('partnerships').doc(invitation.partnershipId);

      final batch = _db.batch();

      // Update invitation status
      batch.update(inviteRef, {
        'status': 'accepted',
        'toUid': uid, // ensure uid is recorded
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Update partnership — same fields as code-based acceptInvite
      batch.update(partnershipRef, {
        'partnerUid': uid,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Read the updated partnership to return
      final partnershipDoc = await partnershipRef.get();
      if (!partnershipDoc.exists) return null;

      final partner = _partnerFromDoc(partnershipDoc);
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] acceptEmailInvite: $invitationId accepted');
      }
      return partner;
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Failed to accept invitation: $e');
    }
  }

  /// Rejects an email-based invitation.
  Future<bool> rejectEmailInvite(String invitationId) async {
    if (!_isReady) return false;
    try {
      final inviteRef = _db.collection('invitations').doc(invitationId);
      final inviteDoc = await inviteRef.get();

      if (!inviteDoc.exists) return false;

      final invitation = AccountabilityInvitation.fromFirestore(
        inviteDoc.data()!,
        id: invitationId,
      );

      final batch = _db.batch();

      batch.update(inviteRef, {
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Also update the linked partnership to declined
      batch.update(
        _db.collection('partnerships').doc(invitation.partnershipId),
        {'status': 'declined'},
      );

      await batch.commit();

      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] rejectEmailInvite: $invitationId rejected');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] rejectEmailInvite error: $e');
      }
      return false;
    }
  }

  // ── Collaborators (Google Keep style) ──────────────────────────────

  /// Collection: task_collaborators/{taskId}
  /// Each doc has: { owner: {uid, email, name, photoUrl}, collaborators: [{uid, email, name, photoUrl}] }

  Collaborator? get currentUserAsCollaborator {
    final user = _auth.currentUser;
    if (user == null) return null;
    return Collaborator(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? user.email?.split('@').first ?? 'User',
      photoUrl: user.photoURL,
    );
  }

  /// Fetch collaborators for a task from Firestore.
  /// [taskId] is the challenge/task id.
  /// Returns (owner, collaborators) tuple.
  Future<({Collaborator owner, List<Collaborator> collaborators})?>
      getTaskCollaborators(String taskId) async {
    if (!_isReady) return null;
    try {
      final doc =
          await _db.collection('task_collaborators').doc(taskId).get();
      if (!doc.exists) {
        final me = currentUserAsCollaborator;
        if (me == null) return null;
        return (owner: me, collaborators: <Collaborator>[]);
      }
      final data = doc.data()!;
      final ownerData = data['owner'] as Map<String, dynamic>?;
      final owner = ownerData != null
          ? Collaborator.fromFirestore(ownerData)
          : currentUserAsCollaborator ?? Collaborator(uid: '', email: '', name: 'Unknown');
      final rawList = data['collaborators'] as List<dynamic>? ?? [];
      final collaborators = rawList
          .map((e) => Collaborator.fromFirestore(e as Map<String, dynamic>))
          .toList();
      return (owner: owner, collaborators: collaborators);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] getTaskCollaborators error: $e');
      }
      return null;
    }
  }

  /// Save collaborators for a task to Firestore.
  Future<bool> saveTaskCollaborators({
    required String taskId,
    required Collaborator owner,
    required List<Collaborator> collaborators,
  }) async {
    if (!_isReady) return false;
    final path = 'task_collaborators/$taskId';
    if (kDebugMode) {
      debugPrint(
          '[AccountabilityService] saveTaskCollaborators: path=$path, ownerUid=${owner.uid}, currentUid=$currentUid, count=${collaborators.length}');
    }
    try {
      await _db.collection('task_collaborators').doc(taskId).set({
        'owner': owner.toFirestore(),
        'collaborators': collaborators.map((c) => c.toFirestore()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] saveTaskCollaborators error: $e');
      }
      return false;
    }
  }

  /// Remove a collaborator from a task.
  Future<bool> removeTaskCollaborator({
    required String taskId,
    required String collaboratorUid,
  }) async {
    if (!_isReady) return false;
    try {
      await _db.collection('task_collaborators').doc(taskId).update({
        'collaborators': FieldValue.arrayRemove([
          {'uid': collaboratorUid}
        ]),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] removeTaskCollaborator error: $e');
      }
      return false;
    }
  }

  /// Add a collaborator to a task.
  Future<bool> addTaskCollaborator({
    required String taskId,
    required Collaborator collaborator,
  }) async {
    if (!_isReady) return false;
    try {
      final docRef = _db.collection('task_collaborators').doc(taskId);
      final doc = await docRef.get();

      if (!doc.exists) {
        final me = currentUserAsCollaborator;
        if (me == null) return false;
        await docRef.set({
          'owner': me.toFirestore(),
          'collaborators': [collaborator.toFirestore()],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.update({
          'collaborators': FieldValue.arrayUnion([collaborator.toFirestore()]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] addTaskCollaborator error: $e');
      }
      return false;
    }
  }

  /// Stream of collaborators for a task.
  Stream<List<Collaborator>> taskCollaboratorsStream(String taskId) {
    if (!_isReady) return const Stream.empty();
    return _db
        .collection('task_collaborators')
        .doc(taskId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return <Collaborator>[];
      final data = snap.data()!;
      final rawList = data['collaborators'] as List<dynamic>? ?? [];
      return rawList
          .map((e) => Collaborator.fromFirestore(e as Map<String, dynamic>))
          .toList();
    });
  }

  // ── Photo Proof ─────────────────────────────────────────────────────────

  /// Submit photo proof for a task. Sets proofStatus → submitted.
  /// Only the accountableUid can submit.
  Future<bool> submitTaskProof({
    required String taskId,
    required String proofUrl,
  }) async {
    if (!_isReady) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] submitTaskProof: service not ready');
      }
      return false;
    }
    if (kDebugMode) {
      debugPrint('[AccountabilityService] submitTaskProof: taskId=$taskId proofUrl=$proofUrl');
    }
    try {
      final now = DateTime.now();
      await _db.collection('accountability_tasks').doc(taskId).update({
        'proofStatus': ProofStatus.submitted.name,
        'proofUrl': proofUrl,
        'proofSubmittedAt': now.toIso8601String(),
      });
      if (kDebugMode) {
        debugPrint('[AccountabilityService] submitTaskProof: SUCCESS — Firestore doc $taskId updated');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] submitTaskProof error: $e');
        debugPrint('[AccountabilityService] submitTaskProof error type: ${e.runtimeType}');
      }
      return false;
    }
  }

  /// Review (approve/reject) a submitted proof.
  /// Only the assigner (assignedByUid) can review.
  Future<bool> reviewTaskProof({
    required String taskId,
    required bool approved,
    String? comment,
  }) async {
    if (!_isReady) return false;
    try {
      final now = DateTime.now();
      final batch = _db.batch();
      final ref = _db.collection('accountability_tasks').doc(taskId);

      if (approved) {
        batch.update(ref, {
          'proofStatus': ProofStatus.approved.name,
          'proofReviewComment': comment,
          'proofReviewedAt': now.toIso8601String(),
          'status': AccountabilityTaskStatus.completed.name,
          'completedAt': now.toIso8601String(),
        });
      } else {
        batch.update(ref, {
          'proofStatus': ProofStatus.rejected.name,
          'proofReviewComment': comment,
          'proofReviewedAt': now.toIso8601String(),
          // Keep task pending so user can resubmit
          'status': AccountabilityTaskStatus.pending.name,
          'completedAt': null,
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] reviewTaskProof error: $e');
      }
      return false;
    }
  }

  /// Fetch tasks with pending (submitted) proof for the current user to review.
  /// These are tasks where current user is the assigner and proof is submitted.
  Future<List<AccountabilityTask>> fetchTasksPendingProofReview() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final snap = await _db
          .collection('accountability_tasks')
          .where('assignedByUid', isEqualTo: uid)
          .where('proofStatus', isEqualTo: ProofStatus.submitted.name)
          .get();
      return snap.docs
          .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchTasksPendingProofReview error: $e');
      }
      return [];
    }
  }

  /// Fetch proof statuses for a list of challenge IDs.
  /// Returns Map<challengeId, ProofStatus>.
  Future<Map<String, ProofStatus>> fetchProofStatusesForChallengeIds(
      List<String> challengeIds) async {
    if (!_isReady || challengeIds.isEmpty) return {};
    try {
      final snap = await _db
          .collection('accountability_tasks')
          .where('challengeId', whereIn: challengeIds)
          .get();
      final map = <String, ProofStatus>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final cid = data['challengeId'] as String?;
        final ps = data['proofStatus'] as String?;
        if (cid != null) {
          map[cid] = ProofStatus.values.firstWhere(
            (e) => e.name == ps,
            orElse: () => ProofStatus.not_required,
          );
        }
      }
      return map;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchProofStatusesForChallengeIds error: $e');
      }
      return {};
    }
  }

  /// Fetches all tasks assigned BY the current user that are already completed.
  /// Used to seed the "already processed" set so the real-time stream
  /// listener doesn't re-trigger auto-completion on initial load.
  Future<List<AccountabilityTask>> fetchAssignedTasksCompleted() async {
    if (!_isReady) return [];
    try {
      final snap = await _db
          .collection('accountability_tasks')
          .where('assignedByUid', isEqualTo: currentUid!)
          .where('status', isEqualTo: AccountabilityTaskStatus.completed.name)
          .get();
      return snap.docs
          .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchAssignedTasksCompleted error: $e');
      }
      return [];
    }
  }

  /// Fetch an accountability task by a challengeId.
  /// Returns the first matching task, or null if none found.
  Future<AccountabilityTask?> fetchTaskByChallengeId(
      String challengeId) async {
    if (!_isReady) return null;
    try {
      final snap = await _db
          .collection('accountability_tasks')
          .where('challengeId', isEqualTo: challengeId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return AccountabilityTask.fromFirestore(
        snap.docs.first.data(),
        id: snap.docs.first.id,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchTaskByChallengeId error: $e');
      }
      return null;
    }
  }

  /// Fetch the accountability task document ID for a challengeId.
  Future<String?> fetchTaskIdByChallengeId(String challengeId) async {
    if (!_isReady) return null;
    try {
      final snap = await _db
          .collection('accountability_tasks')
          .where('challengeId', isEqualTo: challengeId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchTaskIdByChallengeId error: $e');
      }
      return null;
    }
  }

  /// Stream of accountability tasks assigned to the current user
  /// (where I am the accountable person), with real-time updates.
  Stream<List<AccountabilityTask>> myTasksStream() {
    if (!_isReady) return const Stream.empty();
    final uid = currentUid!;
    return _db
        .collection('accountability_tasks')
        .where('accountableUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
            .toList());
  }

  /// Stream of accountability tasks assigned BY the current user
  /// (where I am the assigner), with real-time updates.
  /// Used to detect when a partner completes a task so the owner can
  /// auto-update their local progress.
  Stream<List<AccountabilityTask>> assignedByMeStream() {
    if (!_isReady) return const Stream.empty();
    final uid = currentUid!;
    return _db
        .collection('accountability_tasks')
        .where('assignedByUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
            .toList());
  }

  // ── One-time cleanup ────────────────────────────────────────────────────

  /// One-time cleanup: deletes accountability tasks where accountableUid == assignedByUid
  /// (tasks accidentally assigned to self due to a previous bug).
  /// Safe to call on every app start — it's a no-op if no bad data exists.
  Future<void> cleanupSelfAssignedTasks() async {
    if (!_isReady) return;
    try {
      final uid = currentUid!;
      // Find tasks where I assigned to myself
      final snap = await _db
          .collection('accountability_tasks')
          .where('assignedByUid', isEqualTo: uid)
          .where('accountableUid', isEqualTo: uid)
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] cleanupSelfAssignedTasks: deleted ${snap.docs.length} bad tasks');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] cleanupSelfAssignedTasks error: $e');
      }
    }
  }
}
