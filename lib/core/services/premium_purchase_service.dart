import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'analytics_service.dart';
import 'premium_entitlement_service.dart';

/// Store product identifiers. Create matching products in Google Play
/// Console and App Store Connect before enabling the paywall in production.
class PremiumProducts {
  static const monthly = 'dailymettle_pro_monthly';
  static const yearly = 'dailymettle_pro_yearly';
  static const ids = <String>{monthly, yearly};
}

enum PremiumPurchaseStatus {
  idle,
  loadingProducts,
  purchasing,
  restoring,
  awaitingServerVerification,
  unavailable,
  failed,
}

class PremiumPurchaseState {
  const PremiumPurchaseState({
    required this.status,
    this.products = const [],
    this.error,
  });

  final PremiumPurchaseStatus status;
  final List<ProductDetails> products;
  final String? error;
}

/// Store purchase adapter that never grants premium from a client callback.
///
/// The store purchase is sent through Google Play/App Store, but access is
/// granted only after the trusted backend verifies it and writes
/// `entitlements/{uid}`. This prevents a modified client from self-granting a
/// subscription.
class PremiumPurchaseService {
  PremiumPurchaseService({
    InAppPurchase? store,
    PremiumEntitlementService? entitlements,
    AnalyticsService? analytics,
  })  : _store = store ?? InAppPurchase.instance,
        _entitlements = entitlements ?? PremiumEntitlementService(),
        _analytics = analytics ?? AnalyticsService();

  final InAppPurchase _store;
  final PremiumEntitlementService _entitlements;
  final AnalyticsService _analytics;
  final _stateController = StreamController<PremiumPurchaseState>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  PremiumPurchaseState _state = const PremiumPurchaseState(
    status: PremiumPurchaseStatus.idle,
  );

  PremiumPurchaseState get state => _state;
  Stream<PremiumPurchaseState> get states => _stateController.stream;

  void start() {
    _purchaseSubscription ??= _store.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) => _emit(
        PremiumPurchaseState(
          status: PremiumPurchaseStatus.failed,
          error: error.toString(),
        ),
      ),
    );
  }

  Future<List<ProductDetails>> loadProducts() async {
    _emit(const PremiumPurchaseState(
      status: PremiumPurchaseStatus.loadingProducts,
    ));
    try {
      final available = await _store.isAvailable();
      if (!available) {
        _emit(const PremiumPurchaseState(
          status: PremiumPurchaseStatus.unavailable,
        ));
        return const [];
      }
      final response = await _store.queryProductDetails(PremiumProducts.ids);
      if (response.error != null) {
        _emit(PremiumPurchaseState(
          status: PremiumPurchaseStatus.failed,
          error: response.error!.message,
        ));
        return const [];
      }
      _emit(PremiumPurchaseState(
        status: PremiumPurchaseStatus.idle,
        products: response.productDetails,
      ));
      return response.productDetails;
    } catch (error) {
      _emit(PremiumPurchaseState(
        status: PremiumPurchaseStatus.failed,
        error: error.toString(),
      ));
      return const [];
    }
  }

  Future<bool> purchase(ProductDetails product) async {
    start();
    _emit(PremiumPurchaseState(
      status: PremiumPurchaseStatus.purchasing,
      products: _state.products,
    ));
    await _analytics.logPremiumPurchaseStarted(productId: product.id);
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _emit(PremiumPurchaseState(
          status: PremiumPurchaseStatus.failed,
          products: _state.products,
          error: 'The store did not start the purchase.',
        ));
      }
      return started;
    } catch (error) {
      _emit(PremiumPurchaseState(
        status: PremiumPurchaseStatus.failed,
        products: _state.products,
        error: error.toString(),
      ));
      return false;
    }
  }

  Future<void> restorePurchases() async {
    start();
    _emit(PremiumPurchaseState(
      status: PremiumPurchaseStatus.restoring,
      products: _state.products,
    ));
    await _analytics.logPremiumRestoreStarted();
    try {
      await _store.restorePurchases();
    } catch (error) {
      _emit(PremiumPurchaseState(
        status: PremiumPurchaseStatus.failed,
        products: _state.products,
        error: error.toString(),
      ));
    }
  }

  /// Re-reads the server-controlled entitlement after store processing.
  Future<bool> refreshServerEntitlement() async {
    final premium = await _entitlements.getIsPremium();
    if (premium) {
      await _analytics.logPremiumPurchaseCompleted();
    }
    return premium;
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        _emit(PremiumPurchaseState(
          status: PremiumPurchaseStatus.purchasing,
          products: _state.products,
        ));
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _emit(PremiumPurchaseState(
          status: PremiumPurchaseStatus.awaitingServerVerification,
          products: _state.products,
        ));
        await _analytics.logPremiumPurchase(
          productId: purchase.productID,
          source: purchase.status == PurchaseStatus.restored ? 'iap' : 'iap',
        );
      } else if (purchase.status == PurchaseStatus.error) {
        _emit(PremiumPurchaseState(
          status: PremiumPurchaseStatus.failed,
          products: _state.products,
          error: purchase.error?.message ?? 'Purchase failed.',
        ));
      }

      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
  }

  void _emit(PremiumPurchaseState value) {
    _state = value;
    if (!_stateController.isClosed) _stateController.add(value);
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    await _stateController.close();
  }
}
