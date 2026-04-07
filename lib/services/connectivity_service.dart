import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'fcm_service.dart';
import 'simple_background_check_service.dart';
import 'analytics_service.dart';

/// Manages internet connectivity and lazy Firebase initialization.
/// Firebase services are initialized when internet becomes available.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;
  bool _firebaseInitialized = false;

  bool get isFirebaseReady => _firebaseInitialized;

  /// Try to init Firebase now. Returns true if successful.
  Future<bool> initFirebase() async {
    if (_firebaseInitialized) return true;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      _firebaseInitialized = true;
      // Init dependent services
      try { await FcmService.instance.init(); } catch (_) {}
      try { await SimpleBackgroundCheckService().checkOnAppOpen(); } catch (_) {}
      if (kDebugMode) print('🌐 Firebase initialized successfully');
      return true;
    } catch (e) {
      if (kDebugMode) print('🌐 Firebase init failed: $e');
      return false;
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
