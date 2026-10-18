import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:seventy_five_hard_tracker/firebase_options.dart';
import 'package:seventy_five_hard_tracker/core/services/fcm_service.dart';
import 'package:seventy_five_hard_tracker/core/services/connectivity_reconnect_state.dart';
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
  bool _dependentServicesStarted = false;
  bool _reconnectWorkInFlight = false;
  bool _reconnectRerunRequested = false;
  Timer? _reconnectRetryTimer;
  final ConnectivityReconnectState _reconnectState =
      ConnectivityReconnectState();

  /// Invoked when internet first becomes available and on later reconnects.
  /// Lets callers run sync work without this service knowing about it.
  /// Legacy callback retained for clients that do not return a result.
  Future<void> Function()? onInternetRestored;

  /// Result-bearing reconnect callback. False (or a thrown error) keeps
  /// reconnect work pending and schedules another attempt.
  Future<bool> Function()? onInternetRestoredWithResult;

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

  /// Public connectivity check for feature-level offline handling.
  Future<bool> hasInternet() => _hasInternet();

  /// Try to init Firebase. Only attempts if internet is available.
  /// Returns true if successful, false otherwise.
  Future<bool> initFirebase() async {
    if (_firebaseInitialized) return true;

    if (Firebase.apps.isNotEmpty) {
      _markFirebaseReady();
      return true;
    }

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

      _markFirebaseReady();

      if (kDebugMode) print('🌐 Firebase initialized successfully');
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🌐 Firebase init failed (will retry when online): $e');
      }
      return false;
    }
  }

  void _markFirebaseReady() {
    if (!kIsWeb) {
      try {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('🌐 Crashlytics hook setup failed: $e');
        }
      }
    }
    _firebaseInitialized = true;
    if (_dependentServicesStarted) return;
    _dependentServicesStarted = true;
    // Init dependent services in background — never block
    unawaited(_initDependentServices());
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
  /// When online, initialize Firebase before running pending sync work.
  void startListening() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final hasInternet = result.any((r) => r != ConnectivityResult.none);
      if (_reconnectState.observe(hasInternet)) {
        _reconnectRetryTimer?.cancel();
        if (_reconnectWorkInFlight) {
          _reconnectRerunRequested = true;
          return;
        }
        unawaited(_runReconnectWork());
      }
    });
  }

  Future<void> _runReconnectWork() async {
    if (_reconnectWorkInFlight) {
      _reconnectRerunRequested = true;
      return;
    }
    _reconnectWorkInFlight = true;
    try {
      do {
        _reconnectRerunRequested = false;
        try {
          if (!_firebaseInitialized && !await initFirebase()) {
            if (_reconnectRerunRequested) continue;
            break;
          }
          if (!_reconnectState.workPending) break;
          final restoreWorkWithResult = onInternetRestoredWithResult;
          final restoreWork = onInternetRestored;
          if (restoreWorkWithResult == null && restoreWork == null) {
            _reconnectState.complete(succeeded: false);
            break;
          }
          final succeeded = restoreWorkWithResult != null
              ? await restoreWorkWithResult()
              : await _runLegacyRestoreWork(restoreWork!);
          // A disconnect/reconnect observed during the await needs a fresh
          // pass; don't let this pass clear the newly pending work.
          if (_reconnectRerunRequested) continue;
          _reconnectState.complete(succeeded: succeeded);
          if (!succeeded && !_reconnectRerunRequested) break;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('🌐 Reconnect work failed: $e');
          }
          _reconnectState.complete(succeeded: false);
          if (_reconnectRerunRequested) continue;
          break;
        }
        if (_reconnectRerunRequested) continue;
        if (!_reconnectState.workPending) break;
      } while (_reconnectRerunRequested);
    } finally {
      _reconnectWorkInFlight = false;
      if (_reconnectState.workPending) _scheduleReconnectRetry();
    }
  }

  Future<bool> _runLegacyRestoreWork(Future<void> Function() callback) async {
    await callback();
    return true;
  }

  /// Marks reconnect work pending and schedules a retry. App-resume syncs use
  /// this when they fail even if no new connectivity transition follows.
  void requestReconnectRetry() {
    _reconnectState
      ..observe(false)
      ..observe(true);
    _scheduleReconnectRetry();
  }

  void _scheduleReconnectRetry() {
    _reconnectRetryTimer?.cancel();
    _reconnectRetryTimer = Timer(const Duration(seconds: 10), () {
      if (!_reconnectState.workPending) return;
      unawaited(_runReconnectWork());
    });
  }

  void dispose() {
    _subscription?.cancel();
    _reconnectRetryTimer?.cancel();
  }
}
