import Foundation

@Observable
final class DummyAuthService: AuthServiceProtocol {
    private(set) var currentUser: User?

    private var users: [User] = [
        User(id: "wp8xQu0GlHcS96aqz1UcacLp1792", username: "test1", email: "test1@test.com"),
        User(id: "2", username: "GoalGetter99", email: "goalg@test.com"),
        User(id: "3", username: "ChampionChaser", email: "champ@test.com"),
        User(id: "4", username: "GoalGetter3000", email: "goal3k@test.com"),
        User(id: "5", username: "SportsSpectator", email: "sports@test.com"),
        User(id: "6", username: "TrophyTaker", email: "trophy@test.com"),
        User(id: "7", username: "SportsSavvy", email: "savvy@test.com"),
        User(id: "8", username: "FootballFanatic", email: "fanatic@test.com"),
        User(id: "9", username: "FantasyFan42", email: "fantasy@test.com"),
        User(id: "10", username: "LeagueLegend", email: "legend@test.com"),
        User(id: "11", username: "GameGuru22", email: "guru@test.com"),
        User(id: "12", username: "ChampionshipChase", email: "chase@test.com"),
        User(id: "13", username: "ChampionshipChallenger", email: "challenger@test.com"),
        User(id: "14", username: "GoalGetter2000", email: "goal2k@test.com"),
        User(id: "15", username: "SoccerSensei", email: "sensei@test.com"),
    ]

    private let passwords: [String: String] = [
        "test1@test.com": "password",
        "goalg@test.com": "password",
        "champ@test.com": "password",
        "fanatic@test.com": "password",
        "fantasy@test.com": "password",
        "legend@test.com": "password",
        "guru@test.com": "password",
        "chase@test.com": "password",
        "challenger@test.com": "password",
        "goal2k@test.com": "password",
        "sensei@test.com": "password",
        "sports@test.com": "password",
        "trophy@test.com": "password",
        "savvy@test.com": "password",
        "goal3k@test.com": "password",
    ]

    func login(email: String, password: String) async throws -> User {
        guard let storedPassword = passwords[email],
              storedPassword == password,
              let user = users.first(where: { $0.email == email }) else {
            throw AuthError.invalidCredentials
        }
        currentUser = user
        return user
    }

    func register(email: String, username: String, password: String) async throws -> User {
        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }
        guard !users.contains(where: { $0.email == email }) else {
            throw AuthError.emailAlreadyInUse
        }
        let newUser = User(id: UUID().uuidString, username: username, email: email)
        users.append(newUser)
        currentUser = newUser
        return newUser
    }

    func logout() {
        currentUser = nil
    }

    func restoreSession() async -> User? {
        // Dummy service has no persisted session
        currentUser
    }

    func updateFCMToken(_ token: String) async throws {
        // Dummy service does not persist tokens
        print("[DummyAuth] updateFCMToken (no-op): \(token.prefix(12))…")
    }

    func uploadAvatar(jpegData: Data) async throws -> URL {
        // Dummy service has no remote storage — just throw so callers fall through.
        throw AuthError.unknown("Avatar upload not available in offline mode")
    }
}
