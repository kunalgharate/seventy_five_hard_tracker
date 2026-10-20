import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Premium capabilities are named here so paywall, entitlement, and future
/// IAP/RevenueCat adapters can share one small vocabulary.
enum PremiumFeature {
  unlimitedChallenges,
  advancedInsights,
  customThemes,
}

extension PremiumFeatureX on PremiumFeature {
  /// Stable key for analytics and future entitlement-provider mappings.
  String get analyticsKey {
    switch (this) {
      case PremiumFeature.unlimitedChallenges:
        return 'unlimited_challenges';
      case PremiumFeature.advancedInsights:
        return 'advanced_insights';
      case PremiumFeature.customThemes:
        return 'custom_themes';
    }
  }

  /// All currently listed features require a premium entitlement. Keeping the
  /// guard on the enum makes it possible to add free features later without
  /// changing callers.
  bool get requiresPremium => true;

  bool isAvailable({required bool isPremium}) => !requiresPremium || isPremium;
}

/// Parsed entitlement state.
///
/// Firestore data is intentionally treated as untrusted. Missing, malformed,
/// expired, revoked, or unknown states resolve to a non-premium entitlement.
class PremiumEntitlement {
  const PremiumEntitlement({
    required this.isPremium,
    this.expiresAt,
    this.productId,
    this.source,
  });

  final bool isPremium;
  final DateTime? expiresAt;
  final String? productId;
  final String? source;

  factory PremiumEntitlement.fromFirestore(
    Map<String, dynamic>? data, {
    DateTime? now,
  }) {
    if (data == null || data.isEmpty) {
      return const PremiumEntitlement(isPremium: false);
    }

    final status = _normalizedString(data['status']);
    final explicitFlag = _readBool(
      data['isPremium'] ??
          data['premium'] ??
          data['entitled'] ??
          data['active'],
    );
    var premium = explicitFlag ?? _activeStatusValues.contains(status);

    // A revoked/cancelled state wins over a stale boolean flag.
    if (_inactiveStatusValues.contains(status)) premium = false;

    final rawExpiresAt = data['expiresAt'] ?? data['expirationDate'];
    final expiresAt = _readDate(rawExpiresAt);
    final referenceTime = now ?? DateTime.now();
    if (premium && rawExpiresAt != null && expiresAt == null) {
      premium = false;
    }
    if (premium && expiresAt != null && !expiresAt.isAfter(referenceTime)) {
      premium = false;
    }

    return PremiumEntitlement(
      isPremium: premium,
      expiresAt: expiresAt,
      productId: _normalizedString(data['productId']),
      source: _normalizedString(data['source']),
    );
  }

  /// Alias that keeps parsing convenient for non-Firestore adapters/tests.
  factory PremiumEntitlement.fromMap(
    Map<String, dynamic>? data, {
    DateTime? now,
  }) =>
      PremiumEntitlement.fromFirestore(data, now: now);

  static const Set<String> _activeStatusValues = {
    'active',
    'entitled',
    'premium',
    'subscribed',
    'trial',
    'trialing',
  };

  static const Set<String> _inactiveStatusValues = {
    'cancelled',
    'canceled',
    'expired',
    'inactive',
    'revoked',
  };

  static String? _normalizedString(dynamic value) {
    if (value is! String) return null;
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  static bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
          return true;
        case 'false':
          return false;
      }
    }
    return null;
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is double && value.isFinite) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }
}

/// Reads the server-controlled entitlement at `entitlements/{uid}`.
///
/// Every unavailable path — signed out, Firebase not initialized, offline,
/// permission denied, missing document, or malformed data — resolves to false.
/// Client code can therefore use this service without adding network checks to
/// every premium feature.
class PremiumEntitlementService {
  PremiumEntitlementService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestoreOverride = firestore,
        _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore? get _firestore {
    if (_firestoreOverride != null) return _firestoreOverride;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    if (_authOverride != null) return _authOverride;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  String? get currentUid {
    try {
      final uid = _auth?.currentUser?.uid;
      return uid == null || uid.isEmpty ? null : uid;
    } catch (_) {
      return null;
    }
  }

  /// Current user's entitlement, with a safe offline false default.
  Future<bool> get isPremium => getIsPremium();

  /// Reads one entitlement document. [uid] is injectable for background
  /// workers and tests; normal callers should omit it to use the signed-in UID.
  Future<bool> getIsPremium({String? uid}) async {
    final entitlement = await getEntitlement(uid: uid);
    return entitlement.isPremium;
  }

  Future<PremiumEntitlement> getEntitlement({String? uid}) async {
    final resolvedUid = uid ?? currentUid;
    final firestore = _firestore;
    if (resolvedUid == null || firestore == null) {
      return const PremiumEntitlement(isPremium: false);
    }

    try {
      final snapshot =
          await firestore.collection('entitlements').doc(resolvedUid).get(
                const GetOptions(source: Source.server),
              );
      return PremiumEntitlement.fromFirestore(snapshot.data());
    } catch (_) {
      return const PremiumEntitlement(isPremium: false);
    }
  }

  /// Emits the current user's entitlement and follows Firestore changes.
  /// A stream error becomes one safe `false` value rather than reaching UI code.
  Stream<bool> get isPremiumStream => watchIsPremium();

  Stream<bool> get stream => watchIsPremium();

  Stream<bool> watchIsPremium({String? uid}) async* {
    final resolvedUid = uid ?? currentUid;
    final firestore = _firestore;
    if (resolvedUid == null || firestore == null) {
      yield false;
      return;
    }

    try {
      await for (final snapshot in firestore
          .collection('entitlements')
          .doc(resolvedUid)
          .snapshots(includeMetadataChanges: true)) {
        // A cached entitlement must not grant premium while offline. The
        // listener will emit again when a server-backed snapshot arrives.
        if (snapshot.metadata.isFromCache) {
          yield false;
          continue;
        }
        yield PremiumEntitlement.fromFirestore(snapshot.data()).isPremium;
      }
    } catch (_) {
      yield false;
    }
  }

  Future<bool> canAccess(PremiumFeature feature, {String? uid}) async {
    if (!feature.requiresPremium) return true;
    return getIsPremium(uid: uid);
  }

  Stream<bool> watchFeature(PremiumFeature feature, {String? uid}) {
    if (!feature.requiresPremium) return Stream<bool>.value(true);
    return watchIsPremium(uid: uid);
  }

  /// Pure guard for widgets/services that already have an entitlement value.
  static bool allows(
    PremiumFeature feature, {
    required bool isPremium,
  }) =>
      feature.isAvailable(isPremium: isPremium);
}
