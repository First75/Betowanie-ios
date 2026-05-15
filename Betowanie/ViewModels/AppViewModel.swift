import SwiftUI
import UIKit

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
        prefetchAvatar(for: user)
    }

    func register(email: String, username: String, password: String) async throws {
        let user = try await authService.register(email: email, username: username, password: password)
        currentUser = user
        await refreshUserStats()
        await syncFCMTokenIfAvailable()
        prefetchAvatar(for: user)
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
            prefetchAvatar(for: user)
        }
    }

    /// Warms the avatar cache so the top-right profile button shows the photo
    /// without flicker on the first frame after launch.
    private func prefetchAvatar(for user: User) {
        guard let url = user.photoURL else { return }
        Task.detached(priority: .utility) {
            _ = await AvatarCache.shared.fetch(url)
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

    /// Resizes the picked image, encodes as JPEG, and uploads via the auth service.
    /// On success updates `currentUser.photoURL` and primes the avatar cache so
    /// the new picture is visible immediately, without a download round-trip.
    func uploadAvatar(_ image: UIImage) async throws {
        guard let prepared = Self.preparedJPEG(from: image) else {
            throw AuthError.unknown("Nie udało się przetworzyć zdjęcia")
        }
        let url = try await authService.uploadAvatar(jpegData: prepared.data)
        AvatarCache.shared.store(image: prepared.image, jpegData: prepared.data, for: url.absoluteString)
        if var user = currentUser {
            user.photoURL = url.absoluteString
            currentUser = user
        }
    }

    /// Downscales to a 512×512 square (aspect-fit) and JPEG-encodes at quality 0.8.
    /// Returns both the encoded data (for upload) and the decoded image (for caching).
    /// Keeps avatars well under the 1 MB Storage rule.
    private static func preparedJPEG(from image: UIImage) -> (data: Data, image: UIImage)? {
        let maxDimension: CGFloat = 512
        let size = image.size
        let scale = min(maxDimension / max(size.width, size.height), 1)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        return (data, resized)
    }
}
