import SwiftUI

@Observable
final class AppViewModel {
    var currentUser: User?
    var userPosition: Int = 0
    var userPoints: Int = 0
    var isLoading: Bool = false

    let dataService: any DataServiceProtocol
    let authService: any AuthServiceProtocol

    init(dataService: any DataServiceProtocol, authService: any AuthServiceProtocol) {
        self.dataService = dataService
        self.authService = authService
        self.currentUser = authService.currentUser

        PushNotifications.shared.onTokenUpdate = { [weak self] token in
            guard let self, self.currentUser != nil else { return }
            Task { try? await self.authService.updateFCMToken(token) }
        }
    }

    /// Persists the current FCM token (if any) for the logged-in user.
    /// Call after login/register/session-restore so the most recent token reaches Firestore.
    func syncFCMTokenIfAvailable() async {
        guard currentUser != nil, let token = PushNotifications.shared.fcmToken else { return }
        try? await authService.updateFCMToken(token)
    }

    func login(email: String, password: String) async throws {
        let user = try await authService.login(email: email, password: password)
        currentUser = user
        await refreshUserStats()
        await syncFCMTokenIfAvailable()
    }

    func register(email: String, username: String, password: String) async throws {
        let user = try await authService.register(email: email, username: username, password: password)
        currentUser = user
        await refreshUserStats()
        await syncFCMTokenIfAvailable()
    }

    func logout() {
        authService.logout()
        currentUser = nil
        userPosition = 0
        userPoints = 0
    }

    func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        if let user = await authService.restoreSession() {
            currentUser = user
            await refreshUserStats()
            await syncFCMTokenIfAvailable()
        }
    }

    /// Re-fetches the user profile (including `isActive`) from the auth service.
    /// Used by the inactive-account screen to poll for activation.
    func refreshActiveStatus() async {
        guard let user = await authService.restoreSession() else { return }
        currentUser = user
        if user.isActive {
            await refreshUserStats()
        }
    }

    func refreshUserStats() async {
        guard let user = currentUser else { return }
        let ranking = (try? await dataService.fetchRanking()) ?? []
        if let entry = ranking.first(where: { $0.id == user.id }) {
            userPosition = entry.position
            userPoints = entry.totalPoints
        } else {
            userPosition = ranking.count + 1
            userPoints = 0
        }
    }
}
