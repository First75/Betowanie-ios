import UIKit
import FirebaseMessaging

/// Bridges UIKit application callbacks needed by Firebase Messaging into the SwiftUI app.
/// Wired up via `@UIApplicationDelegateAdaptor` in `BetowanieApp`.
final class BetowanieAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // FirebaseApp.configure() is called in BetowanieApp.init, which runs before this method.
        PushNotifications.shared.configure()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Push] Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
