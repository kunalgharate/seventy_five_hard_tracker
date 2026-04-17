import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCLC3owchDKU0IVzcd25MzXXT_M-UIHddA',
    appId: '1:496007025535:android:f8674a6bdbc2987f34c04a',
    messagingSenderId: '496007025535',
    projectId: 'dailymettle',
    storageBucket: 'dailymettle.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBeWcDsCfdfHboj0Va5K_9HtpF-GK9ZfkU',
    appId: '1:496007025535:ios:193ffb745000941c34c04a',
    messagingSenderId: '496007025535',
    projectId: 'dailymettle',
    storageBucket: 'dailymettle.firebasestorage.app',
    iosBundleId: 'com.example.seventyFiveHardTracker',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAYEzb1o_9BKaCeKijBv-TMkgLl3DM_Fek',
    appId: '1:496007025535:web:a4be8016541bc3de34c04a',
    messagingSenderId: '496007025535',
    projectId: 'dailymettle',
    authDomain: 'dailymettle.firebaseapp.com',
    storageBucket: 'dailymettle.firebasestorage.app',
    measurementId: 'G-3W6RV0E71F',
  );
}
