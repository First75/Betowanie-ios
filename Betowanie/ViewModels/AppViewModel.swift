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
    }

    func login(email: String, password: String) async throws {
        let user = try await authService.login(email: email, password: password)
        currentUser = user
        await refreshUserStats()
    }

    func register(email: String, username: String, password: String) async throws {
        let user = try await authService.register(email: email, username: username, password: password)
        currentUser = user
        await refreshUserStats()
    }

    func logout() {
        authService.logout()
        currentUser = nil
        userPosition = 0
        userPoints = 0
    }

    func restoreSession() async {
        if let user = await authService.restoreSession() {
            currentUser = user
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
