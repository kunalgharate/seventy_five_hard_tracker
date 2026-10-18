import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/data_ownership.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../models/collaborator.dart';
import '../models/accountability_partner.dart';
import '../models/accountability_task.dart';
import '../models/partner_review.dart';
import '../models/app_user.dart';
import '../models/accountability_invitation.dart';
import 'accountability_notification_service.dart';

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

  /// Ensures [registerUser] writes the `users` doc at most once per session.
  bool _registered = false;

  // ── Readiness ────────────────────────────────────────────────────

  bool get _isReady {
    try {
      Firebase.app(); // throws if not initialized
      return _auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Public readiness check — Firebase initialized AND a signed-in user.
  /// Used by offline flows (e.g. the task outbox) to decide whether a
  /// replay can proceed.
  bool get isReady => _isReady;

  String? get currentUid => _auth.currentUser?.uid;

  /// Lower-cased email of the signed-in user, or '' when unavailable.
  String get _myEmail => (_auth.currentUser?.email ?? '').toLowerCase();

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
    // Tolerate missing fields — one malformed doc must never throw and
    // empty the entire partner list for the user.
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AccountabilityPartner(
      id: data['id'] as String? ?? doc.id,
      ownerUid: data['ownerUid'] as String? ?? '',
      partnerUid: data['partnerUid'] as String?,
      partnerName: data['partnerName'] as String? ?? '',
      ownerName: data['ownerName'] as String?,
      partnerEmail: data['partnerEmail'] as String?,
      ownerEmail: data['ownerEmail'] as String?,
      role:
          PartnerRoleExtension.fromString(data['role'] as String? ?? 'friend'),
      status: PartnershipStatusExtension.fromString(
          data['status'] as String? ?? 'pending'),
      inviteCode: data['inviteCode'] as String? ?? '',
      inviteType: data['inviteType'] as String? ?? 'code',
      invitationId: data['invitationId'] as String?,
      createdAt: _parseDate(data['createdAt']),
      acceptedAt:
          data['acceptedAt'] != null ? _parseDate(data['acceptedAt']) : null,
    );
  }

  /// Reads a display name from the `users` collection. Used for partnership
  /// docs written before the `ownerName` field existed.
  Future<String?> _fetchUserDisplayName(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data();
      if (data == null) return null;
      final name = data['displayName'] as String?;
      if (name != null && name.isNotEmpty) return name;
      final email = data['email'] as String?;
      if (email != null && email.isNotEmpty) return email.split('@').first;
    } catch (_) {
      // Name resolution is cosmetic — never fail the caller over it.
    }
    return null;
  }

  /// A partnership doc is shared by both users and `partnerName` always
  /// holds the *invitee's* name.
  ///
  /// • Owner side (I created the invite): `partnerName` is the other person
  ///   — leave it alone.
  /// • Invitee side (they invited me): `partnerName` is my own name, so it
  ///   is swapped for `ownerName` (the inviter) — the UI then always shows
  ///   the other person.
  Future<AccountabilityPartner> _resolvePartnerName(
    AccountabilityPartner partner,
  ) async {
    final myUid = currentUid;
    // I'm the inviter (or signed out) — nothing to correct.
    if (myUid == null || partner.ownerUid == myUid) return partner;
    var ownerName = partner.ownerName;
    if (ownerName == null || ownerName.isEmpty) {
      ownerName = await _fetchUserDisplayName(partner.ownerUid);
    }
    // The inviter's email is needed so the invitee sees the partner's
    // address, not their own (`partnerEmail` is always the invitee's).
    var ownerEmail = partner.ownerEmail;
    if (ownerEmail == null || ownerEmail.isEmpty) {
      ownerEmail = await _fetchUserEmail(partner.ownerUid);
    }
    if (ownerEmail == null || ownerEmail.isEmpty) {
      ownerEmail = await _fetchInvitationSenderEmail(partner.invitationId);
    }
    if ((ownerName == null || ownerName.isEmpty) &&
        (ownerEmail == null || ownerEmail.isEmpty)) {
      return partner;
    }
    return partner.copyWith(
      partnerName: (ownerName != null && ownerName.isNotEmpty)
          ? ownerName
          : partner.partnerName,
      ownerName: (ownerName != null && ownerName.isNotEmpty)
          ? ownerName
          : partner.ownerName,
      partnerEmail: (ownerEmail != null && ownerEmail.isNotEmpty)
          ? ownerEmail
          : partner.partnerEmail,
      ownerEmail: (ownerEmail != null && ownerEmail.isNotEmpty)
          ? ownerEmail
          : partner.ownerEmail,
    );
  }

  /// Reads an email from the `users` collection. Best-effort.
  Future<String?> _fetchUserEmail(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final email = snap.data()?['email'] as String?;
      if (email != null && email.isNotEmpty) return email;
    } catch (_) {
      // Cosmetic — never fail the caller over it.
    }
    return null;
  }

  /// Reads the sender's email from a linked invitation doc. Best-effort.
  Future<String?> _fetchInvitationSenderEmail(String? invitationId) async {
    if (invitationId == null || invitationId.isEmpty) return null;
    try {
      final snap = await _db.collection('invitations').doc(invitationId).get();
      final email = snap.data()?['fromEmail'] as String?;
      if (email != null && email.isNotEmpty) return email;
    } catch (_) {
      // Cosmetic — never fail the caller over it.
    }
    return null;
  }

  Future<List<AccountabilityPartner>> _resolveAll(
    Iterable<AccountabilityPartner> partners,
  ) {
    return Future.wait(partners.map(_resolvePartnerName));
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
        'ownerName': currentUserDisplayName,
        'partnerEmail': partnerEmail,
        'ownerEmail': _myEmail,
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
      if (upperCode.isEmpty) {
        // Email invitations carry no code — calling invite_codes.doc('') would
        // throw "document path must be a non-empty string".
        throw Exception(
            'This is an email invitation, not a code invite. Accept it from the invitation card.');
      }

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

      // Use a transaction to claim the partnership atomically. The
      // transaction read is server-side (not subject to client read rules),
      // so we don't need a blanket read rule on pending partnerships.
      final updated = await _db.runTransaction<AccountabilityPartner>(
        (txn) async {
          final partnershipDoc = await txn.get(partnershipRef);

          if (!partnershipDoc.exists) {
            throw Exception(
                'The partnership linked to this code no longer exists. '
                'Ask your partner to create a new invite.');
          }

          final existing = _partnerFromDoc(partnershipDoc);

          if (existing.ownerUid == uid) {
            throw Exception('You cannot accept your own invite code.');
          }
          if (existing.status != PartnershipStatus.pending) {
            throw Exception(
                'This invite has already been accepted or is no longer valid.');
          }

          txn.update(partnershipRef, {
            'partnerUid': uid,
            'status': 'accepted',
            'acceptedAt': FieldValue.serverTimestamp(),
          });

          return _resolvePartnerName(
            existing.copyWith(
              partnerUid: uid,
              status: PartnershipStatus.accepted,
              acceptedAt: DateTime.now(),
            ),
          );
        },
      );

      // Partnership changed — invalidate the cached allowedReaders list
      // so the next publish picks up the new partner.
      invalidateAllowedReaders();

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

  /// Accepts an incoming partner request regardless of how it was created.
  ///
  /// Code-based invites carry a 6-character [AccountabilityPartner.inviteCode];
  /// email invites have no code and are accepted through the linked
  /// `invitations` document instead.
  Future<AccountabilityPartner?> acceptPartnerRequest(
    AccountabilityPartner partner,
  ) async {
    if (partner.inviteCode.isNotEmpty) {
      return acceptInvite(partner.inviteCode);
    }
    var invitationId = partner.invitationId;
    if (invitationId == null || invitationId.isEmpty) {
      // Older email invites were written without an invitationId on the
      // partnership — look it up so they still work.
      invitationId = await _findInvitationIdForPartnership(partner.id);
    }
    if (invitationId == null) {
      throw Exception(
          'This invitation is no longer valid. Ask your partner to send a new one.');
    }
    return acceptEmailInvite(invitationId);
  }

  /// Rejects an incoming partner request (code or email based).
  Future<bool> rejectPartnerRequest(AccountabilityPartner partner) {
    return rejectInvite(partner.id);
  }

  Future<String?> _findInvitationIdForPartnership(String partnershipId) async {
    if (!_isReady) return null;
    try {
      final snap = await _db
          .collection('invitations')
          .where('partnershipId', isEqualTo: partnershipId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] _findInvitationIdForPartnership error: $e');
      }
      return null;
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
      final partners = await _resolveAll(snap.docs.map(_partnerFromDoc));
      // A self-invite (I emailed myself) is not a request from someone else.
      partners.removeWhere((p) => p.ownerUid == uid);
      // Two pending docs from the same person must not show twice.
      final byOwner = <String, AccountabilityPartner>{};
      for (final p in partners) {
        final key = p.ownerUid.isNotEmpty
            ? p.ownerUid
            : p.partnerName.trim().toLowerCase();
        final existing = byOwner[key];
        if (existing == null || _preferPartnership(p, existing)) {
          byOwner[key] = p;
        }
      }
      final deduped = byOwner.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deduped;
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
      // Partnership removed — invalidate the cached allowedReaders list.
      invalidateAllowedReaders();
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

      // Merge and deduplicate by doc ID, then by the other user — two docs
      // for the same pair (double invite, old data) must not show the same
      // person twice. Prefer accepted > pending > declined, then newest.
      final seenDocs = <String>{};
      final byPartner = <String, AccountabilityPartner>{};
      for (final doc in [...ownerQuery.docs, ...partnerQuery.docs]) {
        if (!seenDocs.add(doc.id)) continue;
        final p = _partnerFromDoc(doc);
        final otherUid = p.ownerUid == uid ? (p.partnerUid ?? '') : p.ownerUid;
        final key =
            otherUid.isNotEmpty ? otherUid : p.partnerName.trim().toLowerCase();
        final existing = byPartner[key];
        if (existing == null || _preferPartnership(p, existing)) {
          byPartner[key] = p;
        }
      }
      final resolved = await _resolveAll(byPartner.values.toList());
      resolved.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchMyPartnerships: found ${resolved.length}');
      }
      return resolved;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchMyPartnerships error: $e');
      }
      return [];
    }
  }

  /// Status ranking used when two partnership docs describe the same pair.
  static int _partnershipRank(PartnershipStatus s) {
    switch (s) {
      case PartnershipStatus.accepted:
        return 3;
      case PartnershipStatus.pending:
        return 2;
      case PartnershipStatus.declined:
        return 1;
    }
  }

  /// True when [candidate] should replace [current] for the same partner.
  static bool _preferPartnership(
      AccountabilityPartner candidate, AccountabilityPartner current) {
    final rc = _partnershipRank(candidate.status);
    final rr = _partnershipRank(current.status);
    if (rc != rr) return rc > rr;
    return candidate.createdAt.isAfter(current.createdAt);
  }

  /// Returns the UIDs of the current user's ACCEPTED partners (the other
  /// party in each partnership). Used to populate `allowedReaders` so partners
  /// — and only partners — can read this user's public_progress.
  Future<List<String>> _acceptedPartnerUids() async {
    final myUid = currentUid;
    if (myUid == null) return [];
    final partners = await fetchMyPartnerships();
    final uids = <String>{};
    for (final p in partners) {
      if (p.status != PartnershipStatus.accepted) continue;
      final other = p.ownerUid == myUid ? p.partnerUid : p.ownerUid;
      if (other != null && other.isNotEmpty) uids.add(other);
    }
    return uids.toList();
  }

  /// Keeps `public_progress/{uid}.allowedReaders` in sync with the user's
  /// accepted partners, so Firestore rules can gate partner reads.
  ///
  /// Cached for the session: the first call fetches from Firestore, subsequent
  /// calls reuse the result. Call [invalidateAllowedReaders] when a partnership
  /// is accepted/removed to force a refresh on the next publish.
  List<String>? _cachedAllowedReaders;

  /// Forces the next [_syncAllowedReaders] call to re-fetch from Firestore.
  void invalidateAllowedReaders() => _cachedAllowedReaders = null;

  Future<void> _syncAllowedReaders() async {
    final uid = currentUid;
    if (uid == null) return;
    try {
      _cachedAllowedReaders ??= await _acceptedPartnerUids();
      await _db.collection('public_progress').doc(uid).set(
        {'allowedReaders': _cachedAllowedReaders},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] _syncAllowedReaders error: $e');
      }
    }
  }

  /// Finds a partnership I own that was sent to [email] (any status except
  /// declined). Single-field query on `partnerEmail`, filtered client-side.
  Future<AccountabilityPartner?> _findMyPartnershipByEmail(String email) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      final snap = await _db
          .collection('partnerships')
          .where('partnerEmail', isEqualTo: email)
          .get();
      AccountabilityPartner? best;
      for (final doc in snap.docs) {
        final p = _partnerFromDoc(doc);
        if (p.ownerUid != uid) continue;
        if (p.status == PartnershipStatus.declined) continue;
        if (best == null || _preferPartnership(p, best)) best = p;
      }
      return best;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] _findMyPartnershipByEmail error: $e');
      }
      return null;
    }
  }

  /// Finds an accepted partnership between the current user and [otherUid].
  /// Returns the partnership if found and accepted, otherwise null.
  Future<AccountabilityPartner?> findAcceptedPartnership(
      String otherUid) async {
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
      if (q1.docs.isNotEmpty) {
        return _resolvePartnerName(_partnerFromDoc(q1.docs.first));
      }

      // Query where they're the owner and I'm the partner
      final q2 = await _db
          .collection('partnerships')
          .where('ownerUid', isEqualTo: otherUid)
          .where('partnerUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) {
        return _resolvePartnerName(_partnerFromDoc(q2.docs.first));
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] findAcceptedPartnership error: $e');
      }
      return null;
    }
  }

  /// Finds ANY non-declined partnership with [otherUid], either direction.
  /// Used to avoid creating a second doc for a pair that already has one
  /// (a duplicate doc makes the same person appear twice in the Squad).
  Future<AccountabilityPartner?> findAnyPartnership(String otherUid) async {
    if (!_isReady) return null;
    try {
      final myUid = currentUid!;
      final docs = <DocumentSnapshot>[];
      final q1 = await _db
          .collection('partnerships')
          .where('ownerUid', isEqualTo: myUid)
          .where('partnerUid', isEqualTo: otherUid)
          .get();
      final q2 = await _db
          .collection('partnerships')
          .where('ownerUid', isEqualTo: otherUid)
          .where('partnerUid', isEqualTo: myUid)
          .get();
      docs.addAll(q1.docs);
      docs.addAll(q2.docs);
      AccountabilityPartner? best;
      for (final doc in docs) {
        final p = _partnerFromDoc(doc);
        if (p.status == PartnershipStatus.declined) continue;
        if (best == null || _preferPartnership(p, best)) best = p;
      }
      return best == null ? null : _resolvePartnerName(best);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] findAnyPartnership error: $e');
      }
      return null;
    }
  }

  /// Ensure an accepted partnership exists with [otherUid].
  /// Creates one if none is found. Returns the partnership ID or null.
  Future<String?> ensurePartnership(String otherUid, String otherName,
      {String? type}) async {
    if (!_isReady) return null;
    try {
      // Never create a second doc for a pair that already has one — that is
      // what made the same partner show up twice in the Squad list.
      final existing = await findAnyPartnership(otherUid);
      if (existing != null) {
        if (existing.status == PartnershipStatus.accepted) {
          if (kDebugMode) {
            debugPrint(
                '[AccountabilityService] ensurePartnership: existing partnership ${existing.id}');
          }
          return existing.id;
        }
        // A pending partnership already links us — upgrade it to accepted
        // instead of creating a duplicate.
        final now = DateTime.now();
        await _db.collection('partnerships').doc(existing.id).update({
          'status': 'accepted',
          'acceptedAt': now.toIso8601String(),
          'partnerName': otherName,
          'ownerName': currentUserDisplayName,
          'ownerEmail': _myEmail,
        });
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] ensurePartnership: upgraded pending ${existing.id}');
        }
        return existing.id;
      }

      final myUid = currentUid!;
      final code = _generateCode();
      final docRef = _db.collection('partnerships').doc();
      final now = DateTime.now();

      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] ensurePartnership: creating new partnership with $otherUid ($otherName)');
      }

      await docRef.set({
        'id': docRef.id,
        'ownerUid': myUid,
        'partnerUid': otherUid,
        'partnerName': otherName,
        'ownerName': currentUserDisplayName,
        'ownerEmail': _myEmail,
        'role': PartnerRole.friend.name,
        'status': 'accepted',
        'inviteCode': code,
        'createdAt': now.toIso8601String(),
        'acceptedAt': now.toIso8601String(),
      });

      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] ensurePartnership: created ${docRef.id}');
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
      // Never publish another account's local data to my progress docs.
      if (await DataOwnership.ownedByOther(uid)) return;
      // Ensure partner read-access list is current before publishing.
      await _syncAllowedReaders();
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
      // Never publish another account's local data to my progress docs.
      if (await DataOwnership.ownedByOther(uid)) return;
      _cachedAllowedReaders ??= await _acceptedPartnerUids();
      await _db.collection('public_progress').doc(uid).set({
        'challengeNames': challengeNames,
        'currentDay': currentDay,
        'allowedReaders': _cachedAllowedReaders,
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
        .asyncMap((snap) => _resolveAll(snap.docs.map(_partnerFromDoc)));
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
  ///
  /// [partnerUid] is the UID that must REVIEW the task (the accountability
  /// partner relative to the doer); without it the review queues
  /// (partnerUid == myUid) and review-time notifications never see the task.
  /// [taskType] is 'hard' (75 Hard) or 'regular'; score branching reads it.
  Future<AccountabilityTask?> createAccountabilityTask({
    required String accountableUid,
    required String accountableName,
    String partnershipId = '',
    required String title,
    String? description,
    DateTime? dueDate,
    String? challengeId,
    List<String>? accountableUserIds,
    String? accountableEmail,
    String? partnerUid,
    String? taskType,
  }) async {
    if (!_isReady) return null;
    // An empty accountableUid makes the task invisible to everyone — unless
    // it is addressed by email, in which case it is claimed when that email
    // signs in (see claimTasksAssignedToMyEmail).
    if (accountableUid.isEmpty &&
        (accountableEmail == null || accountableEmail.isEmpty)) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] createTask: refusing task with empty accountableUid (title="$title")');
      }
      return null;
    }
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
        accountableUserIds: accountableUid.isEmpty
            ? const []
            : (accountableUserIds ?? [accountableUid]),
        accountableEmail: accountableEmail,
        partnerUid: partnerUid,
        taskType: taskType ?? 'hard',
      );
      await ref.set(task.toFirestore());
      // Join the task's FCM topic on the owner's device now; assigned
      // reviewers are notified so the recipient's delivery listener can
      // surface the assignment (never blocks task creation on failure).
      unawaited(FcmService.instance.subscribeToTaskChannel(ref.id));
      try {
        await _notifyTaskAssigned(task);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AccountabilityService] createTask notify error: $e');
        }
      }
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

  /// Sends a "task assigned" notification to every assigned user (the
  /// accountable uid plus any extra reviewer ids) except the creator.
  Future<void> _notifyTaskAssigned(AccountabilityTask task) async {
    final svc = AccountabilityNotificationService();
    final assignees = <String>{
      if (task.accountableUid.isNotEmpty) task.accountableUid,
      ...task.accountableUserIds,
    }.where((uid) => uid.isNotEmpty && uid != currentUid);
    for (final uid in assignees) {
      await svc.notifyTaskAssigned(
        recipientUid: uid,
        ownerName: task.assignedByName,
        taskName: task.title,
        taskId: task.id,
      );
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

  /// Returns Map<challengeId, AccountabilityTaskStatus> for tasks where
  /// the current user is the accountable person. Used to show status chips.
  Future<Map<String, AccountabilityTaskStatus>>
      fetchMyAccountabilityTaskStatuses() async {
    if (!_isReady) return {};
    try {
      final snap = await _db
          .collection('accountability_tasks')
          .where('accountableUid', isEqualTo: currentUid!)
          .get();
      final map = <String, AccountabilityTaskStatus>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final cid = data['challengeId'] as String?;
        final status = AccountabilityTaskStatusExtension.fromString(
            data['status'] as String? ?? 'pending');
        if (cid != null && cid.isNotEmpty) {
          map[cid] = status;
        }
      }
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchMyAccountabilityTaskStatuses: ${map.length} entries');
      }
      return map;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchMyAccountabilityTaskStatuses error: $e');
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

  /// Challenge IDs of tasks a partner assigned TO me (I am the reviewer).
  ///
  /// Under the owner-completes model those challenges belong to the owner's
  /// session only; this is used to strip local copies from my session.
  Future<Set<String>> fetchReviewerChallengeIds() async {
    if (!_isReady) return {};
    try {
      final uid = currentUid!;
      final snap = await _db
          .collection('accountability_tasks')
          .where('accountableUid', isEqualTo: uid)
          .get();
      final ids = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        // Tasks I assigned to myself are mine to complete.
        if ((data['assignedByUid'] as String?) == uid) continue;
        final cid = data['challengeId'] as String?;
        if (cid != null && cid.isNotEmpty) ids.add(cid);
      }
      return ids;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchReviewerChallengeIds error: $e');
      }
      return {};
    }
  }

  /// Fetches a single accountability task by its Firestore document ID.
  Future<AccountabilityTask?> fetchTaskById(String taskId) async {
    if (!_isReady) return null;
    try {
      final doc =
          await _db.collection('accountability_tasks').doc(taskId).get();
      if (!doc.exists) return null;
      return AccountabilityTask.fromFirestore(doc.data()!, id: doc.id);
    } catch (e) {
      debugPrint('[AccountabilityService] fetchTaskById error: $e');
      return null;
    }
  }

  /// Fetches incoming task requests for the current user
  /// (tasks where accountableUid == myUid && status is requested or pending).
  /// Claim tasks that were addressed to my email before I had an account.
  ///
  /// When a coach/manager assigns a task to an email that has not joined yet,
  /// the task is written with an empty accountableUid but the target email in
  /// accountableEmail. Once that email signs in, this claims the tasks so the
  /// partner sees the "X invited you to review this task" card.
  Future<void> claimTasksAssignedToMyEmail() async {
    if (!_isReady) return;
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null || email.isEmpty) return;
    final uid = currentUid!;
    try {
      final snap = await _db
          .collection('accountability_tasks')
          .where('accountableEmail', isEqualTo: email)
          .get();
      final docs = snap.docs.where((d) {
        final data = d.data();
        final addr = (data['accountableUid'] as String?) ?? '';
        final status = (data['status'] as String?) ?? '';
        return (addr.isEmpty || addr == uid) &&
            status != AccountabilityTaskStatus.declined.name;
      }).toList();
      for (final doc in docs) {
        final data = doc.data();
        final ids =
            (data['accountableUserIds'] as List<dynamic>?)?.cast<String>() ??
                [];
        if (!ids.contains(uid)) ids.add(uid);
        await doc.reference.update({
          'accountableUid': uid,
          'accountableUserIds': ids,
        });
        if (kDebugMode) {
          debugPrint('[AccountabilityService] claimed task ${doc.id} by email');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] claimTasksAssignedToMyEmail error: $e');
      }
    }
  }

  /// Fetch task requests addressed to my uid OR to my email (not yet claimed).
  Future<List<AccountabilityTask>> fetchIncomingTaskRequests() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final email = _auth.currentUser?.email?.toLowerCase();
      final snap = await _db
          .collection('accountability_tasks')
          .where('accountableUid', isEqualTo: uid)
          .get();
      final tasks = snap.docs
          .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
          .where((t) => t.status == AccountabilityTaskStatus.requested)
          .toList();
      if (email != null && email.isNotEmpty) {
        final emailed = await _db
            .collection('accountability_tasks')
            .where('accountableEmail', isEqualTo: email)
            .get();
        for (final d in emailed.docs) {
          if (tasks.any((t) => t.id == d.id)) continue;
          final t = AccountabilityTask.fromFirestore(d.data(), id: d.id);
          if (t.status == AccountabilityTaskStatus.requested &&
              (t.accountableUid.isEmpty || t.accountableUid == uid)) {
            tasks.add(t);
          }
        }
      }
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
      final data = doc.data()!;
      final uid = currentUid!;
      final email = _auth.currentUser?.email?.toLowerCase();
      final isMine = data['accountableUid'] == uid ||
          ((email != null && email.isNotEmpty) &&
              (data['accountableEmail'] as String?)?.toLowerCase() == email);
      if (!isMine) return false;
      // Accepting also claims the task if it was addressed by email only.
      final ids =
          (data['accountableUserIds'] as List<dynamic>?)?.cast<String>() ?? [];
      if (!ids.contains(uid)) ids.add(uid);
      final update = <String, dynamic>{
        'status': AccountabilityTaskStatus.pending.name,
        'accountableUid': uid,
        'accountableUserIds': ids,
      };
      // Email-claimed tasks have no reviewer yet. The creator reviews the
      // acceptor's work — backfilling here makes submitForReview notifications
      // and the review queues (partnerUid == uid) reach them.
      final partnerUid = data['partnerUid'] as String?;
      if (partnerUid == null || partnerUid.isEmpty) {
        final creatorUid = data['assignedByUid'] as String?;
        if (creatorUid != null && creatorUid.isNotEmpty) {
          update['partnerUid'] = creatorUid;
        }
      }
      await ref.update(update);
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

  /// Cancel an accountability task — sets status to declined.
  Future<void> cancelAccountabilityTask(String taskId) async {
    if (!_isReady) return;
    try {
      await _db
          .collection('accountability_tasks')
          .doc(taskId)
          .update({'status': AccountabilityTaskStatus.declined.name});
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] cancelAccountabilityTask error: $e');
      }
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

      // Q1: partnershipId match — but SCOPED to the current user, because the
      // security rules reject an unscoped partnershipId-only query
      // (permission-denied). A readable task always has the user as either the
      // assigner or the accountable party, so query both and merge.
      futures.add(_db
          .collection('accountability_tasks')
          .where('partnershipId', isEqualTo: partnershipId)
          .where('assignedByUid', isEqualTo: myUid)
          .get());
      futures.add(_db
          .collection('accountability_tasks')
          .where('partnershipId', isEqualTo: partnershipId)
          .where('accountableUid', isEqualTo: myUid)
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
        // Both owner and reviewer must see the same lifecycle: pending,
        // completed, and every review state (pendingReview/approved/rejected/
        // expired). Hiding pendingReview is what made approvals invisible
        // on one side.
        if (t.status == AccountabilityTaskStatus.pending ||
            t.status == AccountabilityTaskStatus.completed ||
            t.status == AccountabilityTaskStatus.pendingReview ||
            t.status == AccountabilityTaskStatus.approved ||
            t.status == AccountabilityTaskStatus.rejected ||
            t.status == AccountabilityTaskStatus.expired) {
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
  ///
  /// The security rules reject an unscoped partnershipId-only snapshot query
  /// (permission-denied) — same reason fetchTasksForPartnership runs scoped
  /// queries. So listen to three scoped snapshot streams — tasks I assigned,
  /// tasks I'm accountable for, and tasks I must review — merge them into one
  /// output, and dedupe by doc id with a latest-wins map (self-assigned tasks
  /// match two of the scopes).
  Stream<List<AccountabilityTask>> tasksStream(String partnershipId) {
    if (!_isReady) return const Stream.empty();
    final myUid = currentUid!;
    final base = _db.collection('accountability_tasks');

    // Subscriptions start paused so the Firestore listeners only attach when
    // the returned stream is actually listened to (matching the lazy
    // behavior of raw .snapshots()).
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final controller = StreamController<List<AccountabilityTask>>(
      onListen: () {
        for (final sub in subs) {
          sub.resume();
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
        subs.clear();
      },
    );

    // Latest doc snapshot per id across all three roles; self-assigned
    // tasks (assignedByUid == accountableUid) otherwise appear twice.
    final latest = <String, DocumentSnapshot<Map<String, dynamic>>>{};

    void emit() {
      final tasks = latest.values
          .map((d) => AccountabilityTask.fromFirestore(d.data()!, id: d.id))
          .toList();
      tasks.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
      if (!controller.isClosed) controller.add(tasks);
    }

    for (final uidField in ['assignedByUid', 'accountableUid', 'partnerUid']) {
      final sub = base
          .where('partnershipId', isEqualTo: partnershipId)
          .where(uidField, isEqualTo: myUid)
          .snapshots()
          .listen((snap) {
        for (final doc in snap.docs) {
          latest[doc.id] = doc;
        }
        emit();
      }, onError: (Object e) {
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] tasksStream($uidField) error: $e');
        }
        if (!controller.isClosed) controller.addError(e);
      });
      sub.pause();
      subs.add(sub);
    }

    return controller.stream;
  }

  // ── Phase 1: Users collection ────────────────────────────────────────────

  /// Registers (or updates) the current user in the `users` collection.
  /// Called on every successful sign-in so the record stays fresh.
  /// Safe to call even if the collection doesn't exist yet — Firestore
  /// creates it on the first write.
  Future<void> registerUser() async {
    if (!_isReady || _registered) return;
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

      _registered = true;
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

  /// Finds an already-added partner by email.
  ///
  /// Checks my partnerships first: the invite flow stores the partner's email
  /// on the partnership doc, so a friend I already added resolves even when
  /// their `users` doc is missing (deleted profile, not re-signed-in yet).
  /// Falls back to the `users` collection lookup.
  Future<AppUser?> findPartnerByEmail(String email) async {
    if (!_isReady) return null;
    final trimmed = email.trim().toLowerCase();
    if (trimmed.isEmpty || !_isReady) return null;
    try {
      final partners = await fetchMyPartnerships();
      for (final p in partners) {
        if (p.status == PartnershipStatus.declined) continue;
        if ((p.emailOf(currentUid) ?? '').toLowerCase() != trimmed) continue;
        final uid = p.uidOf(currentUid) ?? '';
        if (uid.isEmpty) continue;
        return AppUser(
          uid: uid,
          email: trimmed,
          displayName: p.partnerName.isNotEmpty
              ? p.partnerName
              : trimmed.split('@').first,
          createdAt: p.acceptedAt ?? p.createdAt,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] findPartnerByEmail error: $e');
      }
    }
    return findUserByEmail(trimmed);
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
      final doc = snap.docs.first;
      final data = doc.data();
      final user = AppUser.fromFirestore(data);
      // Legacy user docs (written by CloudSyncService) stored the uid under
      // `id` and the name under `name`. Without these fallbacks the invite
      // flow stored partnerUid: '' / partnerName: '' on the partnership,
      // which security rules reject as "not claimable".
      final uid = user.uid.isNotEmpty ? user.uid : doc.id;
      final legacyName = data['name'] as String?;
      final displayName = user.displayName.isNotEmpty
          ? user.displayName
          : ((legacyName?.isNotEmpty ?? false)
              ? legacyName!
              : user.email.split('@').first);
      return AppUser(
        uid: uid,
        email: user.email,
        displayName: displayName,
        photoUrl: user.photoUrl,
        createdAt: user.createdAt,
      );
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

    // Look up recipient: partnerships first (an already-added friend resolves
    // even if their `users` doc is missing), then the users collection.
    final recipient = await findPartnerByEmail(recipientEmail);

    // Never create a second partnership for a person I already added — that
    // is what made the same partner show up twice in the Squad.
    final existing = await _findMyPartnershipByEmail(recipientEmail);
    if (existing != null) {
      if (existing.status == PartnershipStatus.accepted) {
        return AccountabilityInvitation(
          id: existing.invitationId ?? existing.id,
          fromUid: uid,
          fromName: senderName,
          fromEmail: senderEmail,
          toEmail: recipientEmail,
          toUid: existing.partnerUid,
          partnershipId: existing.id,
          role: existing.role,
          status: InvitationStatus.accepted,
          createdAt: existing.createdAt,
          respondedAt: existing.acceptedAt,
        );
      }
      if (existing.invitationId != null && existing.invitationId!.isNotEmpty) {
        // A pending email invite already exists for this pair — return it.
        return AccountabilityInvitation(
          id: existing.invitationId!,
          fromUid: uid,
          fromName: senderName,
          fromEmail: senderEmail,
          toEmail: recipientEmail,
          toUid: existing.partnerUid,
          partnershipId: existing.id,
          role: existing.role,
          status: InvitationStatus.pending,
          createdAt: existing.createdAt,
        );
      }
      // Pending code-invite: upgrade it into an email invite in place.
      final upgradeRef = _db.collection('invitations').doc();
      await _db.collection('partnerships').doc(existing.id).update({
        'partnerEmail': recipientEmail,
        'partnerUid': recipient?.uid,
        'partnerName': (recipient?.displayName.isNotEmpty ?? false)
            ? recipient!.displayName
            : recipientEmail.split('@').first,
        'inviteType': 'email',
        'invitationId': upgradeRef.id,
      });
      final upgraded = AccountabilityInvitation(
        id: upgradeRef.id,
        fromUid: uid,
        fromName: senderName,
        fromEmail: senderEmail,
        toEmail: recipientEmail,
        toUid: recipient?.uid,
        partnershipId: existing.id,
        role: role,
        status: InvitationStatus.pending,
        createdAt: DateTime.now(),
      );
      await upgradeRef.set(upgraded.toFirestore());
      if (recipient?.uid.isNotEmpty ?? false) {
        await _notifyInvitationReceived(
          recipientUid: recipient!.uid,
          partnershipId: existing.id,
        );
      }
      return upgraded;
    }

    // Pre-create the partnership doc (same structure as existing code-based flow)
    final partnershipRef = _db.collection('partnerships').doc();
    final inviteRef = _db.collection('invitations').doc();
    final now = DateTime.now();

    // Never write empty strings for uid/name: security rules treat
    // partnerUid == '' as "claimed by another account", which made the
    // invitee's accept attempt fail with permission-denied.
    final String? recipientUid =
        (recipient?.uid.isNotEmpty ?? false) ? recipient!.uid : null;
    final partnerName = (recipient?.displayName.isNotEmpty ?? false)
        ? recipient!.displayName
        : recipientEmail.split('@').first;

    final batch = _db.batch();

    // Partnership doc — identical shape to existing code-based flow
    batch.set(partnershipRef, {
      'id': partnershipRef.id,
      'ownerUid': uid,
      'partnerUid': recipientUid, // null if not yet registered
      'partnerName': partnerName,
      'ownerName': senderName,
      'partnerEmail': recipientEmail,
      'ownerEmail': senderEmail,
      'role': role.name,
      'status': 'pending',
      'inviteCode': '', // empty — not code-based
      'inviteType': 'email', // distinguishes from code-based invites
      'invitationId': inviteRef.id, // so the invitee can accept without a code
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
      toUid: recipientUid,
      partnershipId: partnershipRef.id,
      role: role,
      status: InvitationStatus.pending,
      createdAt: now,
    );

    batch.set(inviteRef, invitation.toFirestore());

    await batch.commit();

    // Push the invite to the recipient's device if they already have an
    // account (toUid is null for pre-registration invites).
    if (recipientUid != null) {
      await _notifyInvitationReceived(
        recipientUid: recipientUid,
        partnershipId: partnershipRef.id,
      );
    }

    if (kDebugMode) {
      debugPrint(
          '[AccountabilityService] sendEmailInvite: sent to $recipientEmail '
          'partnershipId=${partnershipRef.id} inviteId=${inviteRef.id}');
    }

    return invitation.copyWith(id: inviteRef.id);
  }

  Future<void> _notifyInvitationReceived({
    required String recipientUid,
    required String partnershipId,
  }) async {
    try {
      await AccountabilityNotificationService().notifyInvitationReceived(
        recipientUid: recipientUid,
        senderName: currentUserDisplayName,
        partnershipId: partnershipId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] invite notify error: $e');
      }
    }
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

      // Update-only claim (no pre-read): a pending partnership is NOT
      // readable by the invitee, so a transaction read would itself be
      // denied. The rules allow claiming when partnerUid is null/'' and
      // status becomes 'accepted'.
      final batch = _db.batch();

      batch.update(inviteRef, {
        'status': 'accepted',
        'toUid': uid,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      batch.update(partnershipRef, {
        'partnerUid': uid,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        // Self-heal docs that were created with empty name strings.
        'partnerName': currentUserDisplayName,
        if (invitation.fromName.isNotEmpty) 'ownerName': invitation.fromName,
        if (invitation.fromEmail.isNotEmpty) 'ownerEmail': invitation.fromEmail,
      });

      await batch.commit();

      // Read the updated partnership to return
      final partnershipDoc = await partnershipRef.get();
      if (!partnershipDoc.exists) return null;

      final partner = _partnerFromDoc(partnershipDoc);
      // Partnership accepted — invalidate the cached allowedReaders list.
      invalidateAllowedReaders();
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] acceptEmailInvite: $invitationId accepted');
      }
      return _resolvePartnerName(partner);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
            'Firestore permission denied while accepting this invitation. '
            'This usually means the deployed security rules are out of date — '
            'run: firebase deploy --only firestore:rules');
      }
      rethrow;
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
      final doc = await _db.collection('task_collaborators').doc(taskId).get();
      if (!doc.exists) {
        final me = currentUserAsCollaborator;
        if (me == null) return null;
        return (owner: me, collaborators: <Collaborator>[]);
      }
      final data = doc.data()!;
      final ownerData = data['owner'] as Map<String, dynamic>?;
      final owner = ownerData != null
          ? Collaborator.fromFirestore(ownerData)
          : currentUserAsCollaborator ??
              const Collaborator(uid: '', email: '', name: 'Unknown');
      final rawList = data['collaborators'] as List<dynamic>? ?? [];
      final collaborators = rawList
          .map((e) => Collaborator.fromFirestore(e as Map<String, dynamic>))
          .toList();
      return (owner: owner, collaborators: collaborators);
    } on FirebaseException catch (e) {
      // permission-denied here simply means the current user is neither the
      // owner nor a listed collaborator on this task's collaborators doc —
      // an expected, non-error case. Treat it as "no shared collaborators"
      // (me as sole owner) rather than logging a scary error.
      if (e.code == 'permission-denied') {
        final me = currentUserAsCollaborator;
        if (me == null) return null;
        return (owner: me, collaborators: <Collaborator>[]);
      }
      if (kDebugMode) {
        debugPrint('[AccountabilityService] getTaskCollaborators error: $e');
      }
      return null;
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
        // Flat list of uids (owner + collaborators) so security rules can gate
        // reads with a simple `in` check (rules can't map over object arrays).
        'collaboratorUids': [
          owner.uid,
          ...collaborators.map((c) => c.uid),
        ],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] saveTaskCollaborators error: $e');
      }
      return false;
    }
  }

  /// Remove a collaborator from a task.
  ///
  /// Uses a Firestore transaction so concurrent removals of different
  /// collaborators don't overwrite each other (the plain read-filter-write
  /// pattern has a TOCTOU race).
  Future<bool> removeTaskCollaborator({
    required String taskId,
    required String collaboratorUid,
  }) async {
    if (!_isReady) return false;
    try {
      final ref = _db.collection('task_collaborators').doc(taskId);
      final removed = await _db.runTransaction<bool>((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return false;

        final data = snap.data() ?? {};
        final current = (data['collaborators'] as List?) ?? [];
        final updated = current
            .whereType<Map<String, dynamic>>()
            .where((c) => c['uid'] != collaboratorUid)
            .toList();

        // Nothing matched — nothing to remove.
        if (updated.length == current.length) return false;

        txn.update(ref, {
          'collaborators': updated,
          'collaboratorUids': [
            if (data['owner'] is Map && (data['owner'] as Map)['uid'] != null)
              (data['owner'] as Map)['uid'],
            ...updated.map((c) => c['uid']).whereType<String>(),
          ],
        });
        return true;
      });
      return removed;
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
          'collaboratorUids': [me.uid, collaborator.uid],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Rebuild collaboratorUids from the full list to backfill docs
        // created before this field existed. arrayUnion alone would only
        // append the new uid, leaving legacy collaborators locked out by
        // the security rule that checks this array.
        final data = doc.data() ?? {};
        final ownerUid = (data['owner'] is Map)
            ? (data['owner'] as Map)['uid'] as String?
            : null;
        final existing = (data['collaborators'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map((c) => c['uid'] as String?)
                .whereType<String>()
                .toList() ??
            [];
        final allUids = <String>{
          if (ownerUid != null) ownerUid,
          ...existing,
          collaborator.uid,
        }.toList();

        await docRef.update({
          'collaborators': FieldValue.arrayUnion([collaborator.toFirestore()]),
          'collaboratorUids': allUids,
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
  /// Only the OWNER (assignedByUid) can submit — reviewers cannot.
  Future<bool> submitTaskProof({
    required String taskId,
    required String proofUrl,
  }) async {
    if (!_isReady) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] submitTaskProof: service not ready');
      }
      return false;
    }
    if (kDebugMode) {
      debugPrint(
          '[AccountabilityService] submitTaskProof: taskId=$taskId proofUrl=$proofUrl');
    }
    try {
      final doc =
          await _db.collection('accountability_tasks').doc(taskId).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      // Owner-only: the task owner (assigner) submits proof, never the reviewer.
      if (data['assignedByUid'] != currentUid) {
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] submitTaskProof: denied — only the owner can submit proof');
        }
        return false;
      }
      final now = DateTime.now();
      await _db.collection('accountability_tasks').doc(taskId).update({
        'proofStatus': ProofStatus.submitted.toWire,
        'proofUrl': proofUrl,
        'proofSubmittedAt': now.toIso8601String(),
      });
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] submitTaskProof: SUCCESS — Firestore doc $taskId updated');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] submitTaskProof error: $e');
        debugPrint(
            '[AccountabilityService] submitTaskProof error type: ${e.runtimeType}');
      }
      return false;
    }
  }

  /// Review (approve/reject) a submitted proof.
  /// Only a REVIEWER (accountableUid / accountableUserIds / partnerUid)
  /// can review — the owner cannot approve their own proof.
  Future<bool> reviewTaskProof({
    required String taskId,
    required bool approved,
    String? comment,
  }) async {
    if (!_isReady) return false;
    try {
      final ref = _db.collection('accountability_tasks').doc(taskId);
      final doc = await ref.get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      if (!_isReviewerOf(data, currentUid!)) {
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] reviewTaskProof: denied — only the reviewer can review proof');
        }
        return false;
      }
      final now = DateTime.now();
      final batch = _db.batch();

      if (approved) {
        batch.update(ref, {
          'proofStatus': ProofStatus.approved.toWire,
          'proofReviewComment': comment,
          'proofReviewedAt': now.toIso8601String(),
          'status': AccountabilityTaskStatus.completed.name,
          'completedAt': now.toIso8601String(),
        });
      } else {
        batch.update(ref, {
          'proofStatus': ProofStatus.rejected.toWire,
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
          .where('proofStatus', isEqualTo: ProofStatus.submitted.toWire)
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
          map[cid] = ProofStatusExtension.fromWire(ps);
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
        debugPrint(
            '[AccountabilityService] fetchAssignedTasksCompleted error: $e');
      }
      return [];
    }
  }

  /// Fetch an accountability task by a challengeId.
  /// Returns the first matching task, or null if none found.
  Future<AccountabilityTask?> fetchTaskByChallengeId(String challengeId) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      // Scope the query to the current user (as creator) so it satisfies the
      // accountability_tasks read rule — an unscoped challengeId-only query is
      // rejected with permission-denied.
      final snap = await _db
          .collection('accountability_tasks')
          .where('challengeId', isEqualTo: challengeId)
          .where('assignedByUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return AccountabilityTask.fromFirestore(
        snap.docs.first.data(),
        id: snap.docs.first.id,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchTaskByChallengeId error: $e');
      }
      return null;
    }
  }

  /// Fetch the accountability task document ID for a challengeId.
  Future<String?> fetchTaskIdByChallengeId(String challengeId) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      // Scope the query to the current user (as creator) so it satisfies the
      // accountability_tasks read rule — an unscoped challengeId-only query is
      // rejected with permission-denied (same as fetchTaskByChallengeId).
      final snap = await _db
          .collection('accountability_tasks')
          .where('challengeId', isEqualTo: challengeId)
          .where('assignedByUid', isEqualTo: uid)
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

  /// One-time cleanup: deletes accountability tasks with no valid challengeId
  /// or where the challenge no longer exists (orphaned tasks).
  Future<void> migrateOrphanedAccountabilityTasks() async {
    if (!_isReady) return;
    try {
      final snap = await _db
          .collection('accountability_tasks')
          .where('accountableUid', isEqualTo: currentUid!)
          .get();
      final batch = _db.batch();
      var count = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final cid = data['challengeId'] as String?;
        if (cid == null || cid.isEmpty) {
          batch.delete(doc.reference);
          count++;
        }
      }
      if (count > 0) {
        await batch.commit();
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] migrateOrphanedAccountabilityTasks: deleted $count orphaned tasks');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] migrateOrphanedAccountabilityTasks error: $e');
      }
    }
  }

  // ── Partner Review Workflow ────────────────────────────────────────────────

  /// Submits a task for partner review. Sets status to pendingReview,
  /// records submittedAt and expiresAt (now + 24h).
  ///
  /// Runs in a transaction so a concurrent expiry batch can't overwrite a
  /// review submitted in-flight.
  ///
  /// Returns the updated task, or null on failure/invalid transition.
  Future<AccountabilityTask?> submitForReview(String taskId) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      final ref = _db.collection('accountability_tasks').doc(taskId);
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      final submitted = await _db.runTransaction<AccountabilityTask?>(
        (txn) async {
          final doc = await txn.get(ref);
          if (!doc.exists) return null;
          final task =
              AccountabilityTask.fromFirestore(doc.data()!, id: doc.id);

          // Validate: only the accountable user can submit for review
          if (task.accountableUid != uid) return null;
          // Validate: must be in pending/accepted state
          if (task.status != AccountabilityTaskStatus.pending) return null;

          txn.update(ref, {
            'status': 'pendingReview',
            'submittedAt': Timestamp.fromDate(now),
            'expiresAt': Timestamp.fromDate(expiresAt),
          });

          return task.copyWith(
            status: AccountabilityTaskStatus.pendingReview,
            submittedAt: now,
            expiresAt: expiresAt,
          );
        },
      );
      return submitted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] submitForReview error: $e');
      }
      return null;
    }
  }

  /// Partner approves a task. Validates that the caller is the assigned partner.
  ///
  /// Runs in a transaction so a concurrent expiry can't overwrite the
  /// review decision (TOCTOU on the get-then-update it replaces).
  ///
  /// Returns the updated task, or null on failure/unauthorized.
  Future<AccountabilityTask?> approveTask(
    String taskId, {
    String? improvementNote,
  }) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      final ref = _db.collection('accountability_tasks').doc(taskId);
      final now = DateTime.now();

      final approved = await _db.runTransaction<AccountabilityTask?>(
        (txn) async {
          final doc = await txn.get(ref);
          if (!doc.exists) return null;
          final task =
              AccountabilityTask.fromFirestore(doc.data()!, id: doc.id);

          // Validate: only the partner can approve
          if (task.partnerUid != uid && task.assignedByUid != uid) {
            return null;
          }
          // Validate: must be in pendingReview state
          if (task.status != AccountabilityTaskStatus.pendingReview) {
            return null;
          }
          // Validate: not already reviewed
          if (task.reviewedAt != null) return null;
          // Validate: not expired
          if (task.expiresAt != null &&
              DateTime.now().isAfter(task.expiresAt!)) {
            return null;
          }

          final updateData = <String, dynamic>{
            'status': 'approved',
            'reviewedAt': Timestamp.fromDate(now),
            'reviewDecision': 'approved',
            'completedAt': Timestamp.fromDate(now),
          };
          if (improvementNote != null && improvementNote.length <= 500) {
            updateData['reviewComment'] = improvementNote;
          }
          txn.update(ref, updateData);

          return task.copyWith(
            status: AccountabilityTaskStatus.approved,
            reviewedAt: now,
            reviewDecision: 'approved',
            reviewComment: improvementNote,
            completedAt: now,
          );
        },
      );
      return approved;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] approveTask error: $e');
      }
      return null;
    }
  }

  /// Partner rejects a task. Validates that the caller is the assigned partner.
  ///
  /// Runs in a transaction so a concurrent expiry can't overwrite the
  /// review decision (TOCTOU on the get-then-update it replaces).
  ///
  /// Returns the updated task, or null on failure/unauthorized.
  Future<AccountabilityTask?> rejectTask(
    String taskId, {
    String? improvementNote,
  }) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      final ref = _db.collection('accountability_tasks').doc(taskId);
      final now = DateTime.now();

      final rejected = await _db.runTransaction<AccountabilityTask?>(
        (txn) async {
          final doc = await txn.get(ref);
          if (!doc.exists) return null;
          final task =
              AccountabilityTask.fromFirestore(doc.data()!, id: doc.id);

          // Validate: only the partner can reject
          if (task.partnerUid != uid && task.assignedByUid != uid) {
            return null;
          }
          // Validate: must be in pendingReview state
          if (task.status != AccountabilityTaskStatus.pendingReview) {
            return null;
          }
          // Validate: not already reviewed
          if (task.reviewedAt != null) return null;
          // Validate: not expired
          if (task.expiresAt != null &&
              DateTime.now().isAfter(task.expiresAt!)) {
            return null;
          }

          final updateData = <String, dynamic>{
            'status': 'rejected',
            'reviewedAt': Timestamp.fromDate(now),
            'reviewDecision': 'rejected',
          };
          if (improvementNote != null && improvementNote.length <= 500) {
            updateData['reviewComment'] = improvementNote;
          }
          txn.update(ref, updateData);

          return task.copyWith(
            status: AccountabilityTaskStatus.rejected,
            reviewedAt: now,
            reviewDecision: 'rejected',
            reviewComment: improvementNote,
          );
        },
      );
      return rejected;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] rejectTask error: $e');
      }
      return null;
    }
  }

  /// Fetches tasks that are pending the current user's review.
  /// (tasks where I am the partner and status=pendingReview)
  Future<List<AccountabilityTask>> fetchPendingReviewsForMe() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final snap = await _db
          .collection('accountability_tasks')
          .where('partnerUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pendingReview')
          .get();

      return snap.docs
          .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
          .toList()
        ..sort((a, b) => (a.expiresAt ?? DateTime.now())
            .compareTo(b.expiresAt ?? DateTime.now()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchPendingReviewsForMe error: $e');
      }
      return [];
    }
  }

  /// Fetches all tasks where I am the assigned partner (all statuses).
  Future<List<AccountabilityTask>> fetchMyResponsibilities() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final snap = await _db
          .collection('accountability_tasks')
          .where('partnerUid', isEqualTo: uid)
          .orderBy('assignedAt', descending: true)
          .limit(50)
          .get();

      return snap.docs
          .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchMyResponsibilities error: $e');
      }
      return [];
    }
  }

  // ── Phase 4: Multi-reviewer approval system ─────────────────────────────

  /// Fetches all tasks where the current user is a reviewer and
  /// status == requested (pending accept/decline).
  Future<List<AccountabilityTask>> fetchIncomingReviewRequests() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final snap = await _db
          .collection('accountability_tasks')
          .where('accountableUserIds', arrayContains: uid)
          .where('status', isEqualTo: 'requested')
          .get();
      return snap.docs
          .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
          .where((t) => t.assignedByUid != uid) // exclude own tasks
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchIncomingReviewRequests error: $e');
      }
      return [];
    }
  }

  /// Fetches tasks where the current user is a reviewer and proof has been
  /// submitted (proofStatus == submitted, status == pendingReview).
  Future<List<AccountabilityTask>> fetchTasksToReview() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final snap = await _db
          .collection('accountability_tasks')
          .where('accountableUserIds', arrayContains: uid)
          .where('proofStatus', isEqualTo: ProofStatus.submitted.toWire)
          .get();
      return snap.docs
          .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
          .where((t) => t.assignedByUid != uid) // exclude own tasks
          .where((t) => !t.hasApprovedBy(uid)) // not already reviewed by me
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchTasksToReview error: $e');
      }
      return [];
    }
  }

  /// Fetches tasks where the current user is the owner and status is
  /// pendingReview (awaiting reviewer action).
  Future<List<AccountabilityTask>> fetchMyPendingReviewTasks() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final snap = await _db
          .collection('accountability_tasks')
          .where('assignedByUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pendingReview')
          .get();
      return snap.docs
          .map((d) => AccountabilityTask.fromFirestore(d.data(), id: d.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityService] fetchMyPendingReviewTasks error: $e');
      }
      return [];
    }
  }

  /// Fetches completed review history (approved/rejected/expired) for the
  /// current user — both as owner and reviewer. Limited to last 50.
  ///
  /// Review events are matched on status (approved/rejected/expired) OR proofStatus,
  /// because `reviewTaskProof` finalizes approvals as status 'completed' and
  /// rejections as status 'pending'. Sorting happens in memory: docs approved
  /// that way never get a `reviewedAt`, which orderBy would silently drop.
  Future<List<AccountabilityTask>> fetchReviewHistory() async {
    if (!_isReady) return [];
    try {
      final uid = currentUid!;
      final tasks = _db.collection('accountability_tasks');
      final decidedProof = [
        ProofStatus.approved.toWire,
        ProofStatus.rejected.toWire,
      ];
      final snaps = await Future.wait([
        tasks.where('assignedByUid', isEqualTo: uid).where('status',
            whereIn: ['approved', 'rejected', 'expired']).get(),
        tasks.where('accountableUserIds', arrayContains: uid).where('status',
            whereIn: ['approved', 'rejected', 'expired']).get(),
        tasks
            .where('assignedByUid', isEqualTo: uid)
            .where('proofStatus', whereIn: decidedProof)
            .get(),
        tasks
            .where('accountableUserIds', arrayContains: uid)
            .where('proofStatus', whereIn: decidedProof)
            .get(),
      ]);
      final all = <String, AccountabilityTask>{};
      for (final snap in snaps) {
        for (final d in snap.docs) {
          all[d.id] = AccountabilityTask.fromFirestore(d.data(), id: d.id);
        }
      }
      final list = all.values.toList()
        ..sort((a, b) {
          final at = a.reviewedAt ?? a.proofReviewedAt ?? a.assignedAt;
          final bt = b.reviewedAt ?? b.proofReviewedAt ?? b.assignedAt;
          return bt.compareTo(at);
        });
      return list.take(50).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] fetchReviewHistory error: $e');
      }
      return [];
    }
  }

  /// Accept a review request — status: requested → pending.
  Future<bool> acceptReviewRequest(String taskId) async {
    if (!_isReady) return false;
    try {
      await _db.collection('accountability_tasks').doc(taskId).update({
        'status': AccountabilityTaskStatus.pending.name,
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] acceptReviewRequest error: $e');
      }
      return false;
    }
  }

  /// Decline a review request — status: requested → declined.
  /// Also removes this reviewer from accountableUserIds.
  Future<bool> declineReviewRequest(String taskId) async {
    if (!_isReady) return false;
    try {
      final uid = currentUid!;
      await _db.collection('accountability_tasks').doc(taskId).update({
        'status': AccountabilityTaskStatus.declined.name,
        'accountableUserIds': FieldValue.arrayRemove([uid]),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] declineReviewRequest error: $e');
      }
      return false;
    }
  }

  /// True when [uid] is a designated reviewer of the task described by
  /// raw Firestore [data] — i.e. listed in accountableUserIds/accountableUid
  /// or as partnerUid, and NOT the owner. The owner can never review
  /// their own proof.
  bool _isReviewerOf(Map<String, dynamic> data, String uid) {
    if (data['assignedByUid'] == uid) return false;
    if (data['partnerUid'] == uid) return true;
    if (data['accountableUid'] == uid) return true;
    final ids =
        (data['accountableUserIds'] as List<dynamic>?)?.cast<String>() ?? [];
    return ids.contains(uid);
  }

  /// True when [uid] is the task owner (the assigner who must submit proof).
  bool _isOwnerOf(Map<String, dynamic> data, String uid) =>
      data['assignedByUid'] == uid;

  /// Submit proof and move task to pendingReview status.
  /// Called when the owner toggles a task that has reviewers.
  /// OWNER-ONLY: reviewers cannot submit proof for a task they review.
  Future<AccountabilityTask?> submitProofForReview({
    required String taskId,
    required String proofUrl,
  }) async {
    if (!_isReady) return null;
    try {
      final ref = _db.collection('accountability_tasks').doc(taskId);
      final existing = await ref.get();
      if (!existing.exists) return null;
      if (!_isOwnerOf(existing.data()!, currentUid!)) {
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] submitProofForReview: denied — only the owner can submit proof');
        }
        return null;
      }
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));
      await _db.collection('accountability_tasks').doc(taskId).update({
        'proofStatus': ProofStatus.submitted.toWire,
        'proofUrl': proofUrl,
        'proofSubmittedAt': Timestamp.fromDate(now),
        'status': AccountabilityTaskStatus.pendingReview.name,
        'submittedAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
      final doc =
          await _db.collection('accountability_tasks').doc(taskId).get();
      if (!doc.exists) return null;
      return AccountabilityTask.fromFirestore(doc.data()!, id: doc.id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] submitProofForReview error: $e');
      }
      return null;
    }
  }

  /// Reviewer approves a proof. Adds to the approvals array.
  /// REVIEWER-ONLY: the owner cannot approve their own proof.
  /// Returns the updated task (with hasEnoughApprovals check).
  Future<AccountabilityTask?> approveProof({
    required String taskId,
    String? comment,
  }) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      final preDoc =
          await _db.collection('accountability_tasks').doc(taskId).get();
      if (!preDoc.exists) return null;
      if (!_isReviewerOf(preDoc.data()!, uid)) {
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] approveProof: denied — only the reviewer can approve');
        }
        return null;
      }
      // Prevent double-voting by the same reviewer.
      final preTask =
          AccountabilityTask.fromFirestore(preDoc.data()!, id: preDoc.id);
      if (preTask.hasApprovedBy(uid)) return preTask;
      final name = currentUserDisplayName;
      final now = DateTime.now();

      final approval = {
        'uid': uid,
        'name': name,
        'timestamp': Timestamp.fromDate(now),
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      };

      await _db.collection('accountability_tasks').doc(taskId).update({
        'approvals': FieldValue.arrayUnion([approval]),
        'proofReviewedAt': Timestamp.fromDate(now),
      });

      // Re-read to check if enough approvals
      final doc =
          await _db.collection('accountability_tasks').doc(taskId).get();
      if (!doc.exists) return null;
      final task = AccountabilityTask.fromFirestore(doc.data()!, id: doc.id);

      // If enough approvals, auto-complete
      if (task.hasEnoughApprovals) {
        await _db.collection('accountability_tasks').doc(taskId).update({
          'status': AccountabilityTaskStatus.approved.name,
          'proofStatus': ProofStatus.approved.toWire,
          'reviewDecision': 'approved',
          'reviewedAt': Timestamp.fromDate(now),
          'completedAt': Timestamp.fromDate(now),
        });
        return task.copyWith(
          status: AccountabilityTaskStatus.approved,
          proofStatus: ProofStatus.approved,
          reviewDecision: 'approved',
          completedAt: now,
        );
      }

      return task;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] approveProof error: $e');
      }
      return null;
    }
  }

  /// Reviewer rejects a proof. Adds to rejections, reverts to pending.
  /// REVIEWER-ONLY: the owner cannot reject their own proof.
  Future<AccountabilityTask?> rejectProof({
    required String taskId,
    required String comment,
  }) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      final preDoc =
          await _db.collection('accountability_tasks').doc(taskId).get();
      if (!preDoc.exists) return null;
      if (!_isReviewerOf(preDoc.data()!, uid)) {
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityService] rejectProof: denied — only the reviewer can reject');
        }
        return null;
      }
      final name = currentUserDisplayName;
      final now = DateTime.now();

      final rejection = {
        'uid': uid,
        'name': name,
        'timestamp': Timestamp.fromDate(now),
        'comment': comment,
      };

      await _db.collection('accountability_tasks').doc(taskId).update({
        'rejections': FieldValue.arrayUnion([rejection]),
        'proofStatus': ProofStatus.rejected.toWire,
        'proofReviewComment': comment,
        'proofReviewedAt': Timestamp.fromDate(now),
        'status': AccountabilityTaskStatus.rejected.name,
        'reviewDecision': 'rejected',
        'reviewedAt': Timestamp.fromDate(now),
      });

      final doc =
          await _db.collection('accountability_tasks').doc(taskId).get();
      if (!doc.exists) return null;
      return AccountabilityTask.fromFirestore(doc.data()!, id: doc.id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityService] rejectProof error: $e');
      }
      return null;
    }
  }

  /// Fetches the count of tasks pending the current user's review action
  /// (incoming requests + submitted proofs). Used for tab badge.
  Future<int> fetchPendingReviewCount() async {
    if (!_isReady) return 0;
    try {
      final requests = await fetchIncomingReviewRequests();
      final toReview = await fetchTasksToReview();
      return requests.length + toReview.length;
    } catch (e) {
      return 0;
    }
  }
}
