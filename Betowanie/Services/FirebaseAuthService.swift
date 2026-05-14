import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firebase Auth + Firestore implementation of AuthServiceProtocol.
///
/// Auth flow:
/// - Firebase Auth handles email/password sign-in and sign-up
/// - User profile (username) is stored in Firestore `users/{uid}`
/// - On register, a Firestore user document is created alongside the auth account
@Observable
final class FirebaseAuthService: AuthServiceProtocol {

    private(set) var currentUser: User?
    private let firestoreDb = Firestore.firestore()

    init() {
        // If Firebase Auth has a persisted session, map it to our User
        if let firebaseUser = Auth.auth().currentUser {
            // We don't have the username yet — it will be loaded in restoreSession()
            currentUser = User(
                id: firebaseUser.uid,
                username: firebaseUser.displayName ?? "",
                email: firebaseUser.email ?? ""
            )
        }
    }

    func login(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        let firebaseUser = result.user

        // Fetch username from Firestore user doc
        let user = try await fetchUserProfile(uid: firebaseUser.uid, email: firebaseUser.email ?? email)
        currentUser = user
        return user
    }

    func register(email: String, username: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let firebaseUser = result.user

        // Update display name on Firebase Auth profile
        let changeRequest = firebaseUser.createProfileChangeRequest()
        changeRequest.displayName = username
        try await changeRequest.commitChanges()

        // Create user document in Firestore. New accounts start inactive
        // and must be activated manually by an admin.
        let userData: [String: Any] = [
            "username": username,
            "email": email,
            "isActive": false,
        ]
        try await firestoreDb
            .collection("users")
            .document(firebaseUser.uid)
            .setData(userData)

        let user = User(id: firebaseUser.uid, username: username, email: email, isActive: false)
        currentUser = user
        return user
    }

    func logout() {
        try? Auth.auth().signOut()
        currentUser = nil
    }

    func updateFCMToken(_ token: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await firestoreDb
            .collection("users")
            .document(uid)
            .setData(
                [
                    "fcmToken": token,
                    "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
                ],
                merge: true
            )
    }

    func restoreSession() async -> User? {
        guard let firebaseUser = Auth.auth().currentUser else {
            currentUser = nil
            return nil
        }

        do {
            let user = try await fetchUserProfile(
                uid: firebaseUser.uid,
                email: firebaseUser.email ?? ""
            )
            currentUser = user
            return user
        } catch {
            print("Failed to restore session: \(error)")
            currentUser = nil
            return nil
        }
    }

    // MARK: - Helpers

    /// Fetches the user's profile from Firestore `users/{uid}` to get the username and active status.
    private func fetchUserProfile(uid: String, email: String) async throws -> User {
        let doc = try await firestoreDb
            .collection("users")
            .document(uid)
            .getDocument()

        let data = doc.exists ? doc.data() : nil
        let username = (data?["username"] as? String)
            ?? Auth.auth().currentUser?.displayName
            ?? "Użytkownik"
        // Default to inactive when missing — admin must explicitly activate accounts.
        let isActive = (data?["isActive"] as? Bool) ?? false

        return User(id: uid, username: username, email: email, isActive: isActive)
    }
}
