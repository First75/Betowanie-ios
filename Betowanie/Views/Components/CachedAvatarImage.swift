import SwiftUI

/// Round avatar image backed by `AvatarCache`. Shows the cached photo when
/// available, falls back to initials on a colored circle otherwise.
struct CachedAvatarImage: View {
    let username: String
    let photoURL: String?
    let size: CGFloat
    let initialsFontSize: CGFloat

    @State private var image: UIImage?

    init(username: String, photoURL: String?, size: CGFloat, initialsFontSize: CGFloat? = nil) {
        self.username = username
        self.photoURL = photoURL
        self.size = size
        self.initialsFontSize = initialsFontSize ?? max(11, size * 0.35)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.terraPrimary
                Text(initials)
                    .font(.system(size: initialsFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: photoURL) {
            await reload()
        }
    }

    private var initials: String {
        let trimmed = username.prefix(2).uppercased()
        return trimmed.isEmpty ? "?" : String(trimmed)
    }

    private func reload() async {
        guard let photoURL else {
            image = nil
            return
        }
        // Synchronous memory hit — avoids flicker on revisit.
        if let cached = AvatarCache.shared.image(for: photoURL) {
            image = cached
            return
        }
        let fetched = await AvatarCache.shared.fetch(photoURL)
        if !Task.isCancelled {
            image = fetched
        }
    }
}
