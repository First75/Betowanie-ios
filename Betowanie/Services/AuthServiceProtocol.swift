import Foundation

protocol AuthServiceProtocol {
    var currentUser: User? { get }
    func login(email: String, password: String) async throws -> User
    func register(email: String, username: String, password: String) async throws -> User
    func logout()

    /// Check if there's a persisted session (e.g. Firebase Auth state)
    func restoreSession() async -> User?
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case userNotFound
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Nieprawidłowy email lub hasło"
        case .emailAlreadyInUse: return "Ten email jest już zajęty"
        case .weakPassword: return "Hasło musi mieć co najmniej 6 znaków"
        case .userNotFound: return "Nie znaleziono użytkownika"
        case .networkError: return "Błąd połączenia z serwerem"
        case .unknown(let msg): return msg
        }
    }
}
