import Foundation
import FirebaseMessaging
import UserNotifications
import UIKit

/// Tracks the latest FCM registration token and forwards updates via `onTokenUpdate`.
/// Wire-up:
/// - `configure()` is called from the app delegate after Firebase is configured.
/// - `requestAuthorization()` is called once the user is logged in.
@Observable
final class PushNotifications: NSObject, @unchecked Sendable {
    static let shared = PushNotifications()

    private(set) var fcmToken: String?

    /// Called on the main thread whenever a new FCM token is received.
    var onTokenUpdate: ((String) -> Void)?

    private override init() { super.init() }

    /// Sets up the Messaging delegate. Safe to call after `FirebaseApp.configure()`.
    func configure() {
        Messaging.messaging().delegate = self
    }

    /// Prompts the user for notification permission and registers with APNs on grant.
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            print("[Push] Authorization granted: \(granted)")
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("[Push] Authorization error: \(error.localizedDescription)")
        }
    }

    private func handleToken(_ token: String?) {
        guard let token, token != fcmToken else { return }
        fcmToken = token
        onTokenUpdate?(token)
    }
}

extension PushNotifications: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.handleToken(fcmToken)
        }
    }
}
