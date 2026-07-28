import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:seventy_five_hard_tracker/firebase_options.dart';
import 'package:seventy_five_hard_tracker/core/services/fcm_service.dart';
import 'package:seventy_five_hard_tracker/services/simple_background_check_service.dart';

/// Manages internet connectivity and lazy Firebase initialization.
/// Firebase services are initialized ONLY when internet is available.
/// The app works fully offline without Firebase.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;
  bool _firebaseInitialized = false;

  bool get isFirebaseReady => _firebaseInitialized;

  /// Check if device currently has internet connectivity.
  Future<bool> _hasInternet() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Try to init Firebase. Only attempts if internet is available.
  /// Returns true if successful, false otherwise.
  Future<bool> initFirebase() async {
    if (_firebaseInitialized) return true;

    // Don't even try if there's no internet
    final hasNet = await _hasInternet();
    if (!hasNet) {
      if (kDebugMode) print('🌐 No internet — skipping Firebase init');
      return false;
    }

    try {
      await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform)
          .timeout(const Duration(seconds: 3));

      // Only initialize Crashlytics if the app is NOT running on a browser
      if (!kIsWeb) {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
      }

      _firebaseInitialized = true;

      // Init dependent services in background — never block
      unawaited(_initDependentServices());

      if (kDebugMode) print('🌐 Firebase initialized successfully');
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🌐 Firebase init failed (will retry when online): $e');
      }
      return false;
    }
  }

  /// Initialize FCM and background check — all wrapped in try-catch.
  Future<void> _initDependentServices() async {
    try {
      await FcmService.instance.init().timeout(const Duration(seconds: 5));
    } catch (e) {
      if (kDebugMode) print('🌐 FCM init failed (non-critical): $e');
    }
    try {
      await SimpleBackgroundCheckService().checkOnAppOpen();
    } catch (e) {
      if (kDebugMode) print('🌐 Background check failed (non-critical): $e');
    }
  }

  /// Start listening for connectivity changes.
  /// When internet becomes available, init Firebase if not already done.
  void startListening() {
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final hasInternet = result.any((r) => r != ConnectivityResult.none);
      if (hasInternet && !_firebaseInitialized) {
        initFirebase();
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
