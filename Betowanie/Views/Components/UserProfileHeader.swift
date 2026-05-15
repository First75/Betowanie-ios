import SwiftUI

/// Avatar + username + optional email. Reused by `ProfileView` (logged-in user)
/// and by user-detail sheets opened from the ranking.
struct UserProfileHeader: View {
    let username: String
    let email: String?
    let photoURL: String?
    /// Optional overlay rendered on top of the avatar (e.g. an edit/camera badge).
    let avatarOverlay: AnyView?

    init(
        username: String,
        email: String? = nil,
        photoURL: String? = nil,
        @ViewBuilder avatarOverlay: () -> some View = { EmptyView() }
    ) {
        self.username = username
        self.email = email
        self.photoURL = photoURL
        let built = avatarOverlay()
        self.avatarOverlay = (built is EmptyView) ? nil : AnyView(built)
    }

    var body: some View {
        VStack(spacing: 12) {
            CachedAvatarImage(
                username: username,
                photoURL: photoURL,
                size: 80,
                initialsFontSize: 28
            )
            .overlay(alignment: .bottomTrailing) {
                if let avatarOverlay {
                    avatarOverlay
                }
            }

            Text(username)
                .font(.terraTitle())
                .foregroundStyle(Color.terraTextPrimary)

            if let email, !email.isEmpty {
                Text(email)
                    .font(.terraCaption())
                    .foregroundStyle(Color.terraTextSecondary)
            }
        }
    }
}
