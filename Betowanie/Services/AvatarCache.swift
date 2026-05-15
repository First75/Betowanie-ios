import UIKit
import CryptoKit

/// Two-tier cache for user avatars: NSCache in memory, JPEG files on disk.
/// Look-ups go memory → disk → network and back-fill each level.
///
/// SwiftUI views call `image(for:)` for an instant synchronous hit and `fetch`
/// for async loads. After a user uploads a new avatar we call `store` so the
/// new image shows up everywhere without a round-trip.
final class AvatarCache: @unchecked Sendable {
    static let shared = AvatarCache()

    private let memory = NSCache<NSString, UIImage>()
    private let cacheDir: URL

    private init() {
        memory.countLimit = 64
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.cacheDir = dir
    }

    /// Instant in-memory lookup. Returns nil if not cached in memory.
    func image(for url: String) -> UIImage? {
        memory.object(forKey: url as NSString)
    }

    /// Memory → disk → network. Populates each level along the way.
    func fetch(_ url: String) async -> UIImage? {
        if let cached = memory.object(forKey: url as NSString) {
            return cached
        }

        if let data = readDisk(for: url), let image = UIImage(data: data) {
            memory.setObject(image, forKey: url as NSString)
            return image
        }

        guard let parsed = URL(string: url) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: parsed),
              let image = UIImage(data: data)
        else {
            return nil
        }
        memory.setObject(image, forKey: url as NSString)
        writeDisk(data: data, for: url)
        return image
    }

    /// Stores an already-decoded image, e.g. immediately after the user uploads
    /// a new avatar so the new picture is visible before any download happens.
    func store(image: UIImage, jpegData: Data, for url: String) {
        memory.setObject(image, forKey: url as NSString)
        writeDisk(data: jpegData, for: url)
    }

    // MARK: - Private

    private func readDisk(for url: String) -> Data? {
        try? Data(contentsOf: cacheURL(for: url))
    }

    private func writeDisk(data: Data, for url: String) {
        try? data.write(to: cacheURL(for: url), options: .atomic)
    }

    private func cacheURL(for url: String) -> URL {
        let hash = SHA256.hash(data: Data(url.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return cacheDir.appendingPathComponent(hash).appendingPathExtension("jpg")
    }
}
