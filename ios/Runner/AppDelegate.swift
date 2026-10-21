import Flutter
import UIKit
import FirebaseCore
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase natively before plugins register. This ensures the
    // native Firebase SDK (Analytics, Crashlytics, Messaging) is initialized
    // from the bundled GoogleService-Info.plist and does not fail at launch.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    
    // Set UNUserNotificationCenter delegate to show notifications when app is in foreground on iOS 10+
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
