import SwiftUI
import UIKit

struct TeamLogoView: View {
    let urlString: String
    let teamName: String
    var size: CGFloat = 36
    var contentMode: ContentMode = .fit
    var clipsToCircle: Bool = true

    private static let teamNameToId: [String: String] = [
        "Uruguay": "758",
        "Germany": "759",
        "Spain": "760",
        "Paraguay": "761",
        "Argentina": "762",
        "Ghana": "763",
        "Brazil": "764",
        "Portugal": "765",
        "Japan": "766",
        "Mexico": "769",
        "England": "770",
        "United States": "771",
        "South Korea": "772",
        "France": "773",
        "South Africa": "774",
        "Algeria": "778",
        "Australia": "779",
        "New Zealand": "783",
        "Switzerland": "788",
        "Ecuador": "791",
        "Sweden": "792",
        "Czechia": "798",
        "Croatia": "799",
        "Saudi Arabia": "801",
        "Tunisia": "802",
        "Turkey": "803",
        "Senegal": "804",
        "Belgium": "805",
        "Morocco": "815",
        "Austria": "816",
        "Colombia": "818",
        "Egypt": "825",
        "Canada": "828",
        "Haiti": "836",
        "Iran": "840",
        "Bosnia-Herzegovina": "1060",
        "Panama": "1836",
        "Cape Verde Islands": "1930",
        "Congo DR": "1934",
        "Ivory Coast": "1935",
        "Qatar": "8030",
        "Jordan": "8049",
        "Iraq": "8062",
        "Uzbekistan": "8070",
        "Netherlands": "8601",
        "Norway": "8872",
        "Scotland": "8873",
        "Curaçao": "9460"
    ]

    private var localAssetName: String? {
        Self.teamNameToId[teamName]
    }

    private var remoteImageURL: URL? {
        guard !urlString.isEmpty else { return nil }

        if urlString.lowercased().hasSuffix(".svg") {
            return URL(string: String(urlString.dropLast(4)) + ".png")
        }

        return URL(string: urlString)
    }

    static func preloadKnownTeamLogos() async {
        await TeamLogoThumbnailCache.shared.preloadAll(
            named: Array(teamNameToId.values),
            targetSizes: [
                CGSize(width: 28, height: 28),
                CGSize(width: 32, height: 32),
                CGSize(width: 36, height: 36),
                CGSize(width: 48, height: 48)
            ],
            contentMode: .fit
        )
    }

    var body: some View {
        if let localAssetName {
            assetImageView(named: localAssetName)
                .frame(width: size, height: size)
                .modifier(TeamLogoClipModifier(clipsToCircle: clipsToCircle))
        } else if let remoteImageURL {
            AsyncImage(url: remoteImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .failure:
                    initialsView
                default:
                    ProgressView()
                        .frame(width: size, height: size)
                }
            }
            .frame(width: size, height: size)
            .modifier(TeamLogoClipModifier(clipsToCircle: clipsToCircle))
        } else {
            initialsView
        }
    }

    @ViewBuilder
    private func assetImageView(named assetName: String) -> some View {
        let targetSize = CGSize(width: size, height: size)

        if let thumbnail = TeamLogoThumbnailCache.shared.image(
            named: assetName,
            targetSize: targetSize,
            contentMode: contentMode
        ) {
            Image(uiImage: thumbnail)
                .resizable()
                .interpolation(.medium)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
        } else {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        }
    }

    private var initialsView: some View {
        let initials = teamName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()

        return Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.terraPrimary.opacity(0.7))
            .clipShape(Circle())
    }
}

private struct TeamLogoClipModifier: ViewModifier {
    let clipsToCircle: Bool

    func body(content: Content) -> some View {
        if clipsToCircle {
            content.clipShape(Circle())
        } else {
            content
        }
    }
}

private final class TeamLogoThumbnailCache {
    static let shared = TeamLogoThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()
    private let preloadLock = NSLock()
    private var preloadedKeys: Set<String> = []

    private init() {
        cache.countLimit = 256
    }

    func image(named assetName: String, targetSize: CGSize, contentMode: ContentMode) -> UIImage? {
        let scale = UIScreen.main.scale
        let cacheKey = cacheKey(
            assetName: assetName,
            targetSize: targetSize,
            contentMode: contentMode,
            scale: scale
        )

        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let sourceImage = UIImage(named: assetName) else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let thumbnail = renderer.image { _ in
            let drawRect = Self.drawingRect(
                for: sourceImage.size,
                in: CGRect(origin: .zero, size: targetSize),
                contentMode: contentMode
            )
            sourceImage.draw(in: drawRect)
        }

        cache.setObject(thumbnail, forKey: cacheKey)
        return thumbnail
    }

    func preloadAll(named assetNames: [String], targetSizes: [CGSize], contentMode: ContentMode) async {
        guard !assetNames.isEmpty, !targetSizes.isEmpty else { return }

        let scale = await MainActor.run { UIScreen.main.scale }

        await withTaskGroup(of: Void.self) { group in
            for assetName in assetNames {
                for targetSize in targetSizes {
                    let cacheKey = cacheKey(
                        assetName: assetName,
                        targetSize: targetSize,
                        contentMode: contentMode,
                        scale: scale
                    )

                    let shouldPreload: Bool = {
                        preloadLock.lock()
                        defer { preloadLock.unlock() }

                        let key = cacheKey as String
                        if preloadedKeys.contains(key) {
                            return false
                        }

                        preloadedKeys.insert(key)
                        return true
                    }()

                    guard shouldPreload else { continue }

                    group.addTask { [cache] in
                        guard let sourceImage = UIImage(named: assetName) else {
                            return
                        }

                        let format = UIGraphicsImageRendererFormat()
                        format.scale = scale
                        format.opaque = false

                        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
                        let thumbnail = renderer.image { _ in
                            let drawRect = Self.drawingRect(
                                for: sourceImage.size,
                                in: CGRect(origin: .zero, size: targetSize),
                                contentMode: contentMode
                            )
                            sourceImage.draw(in: drawRect)
                        }

                        cache.setObject(thumbnail, forKey: cacheKey)
                    }
                }
            }
        }
    }

    private func cacheKey(
        assetName: String,
        targetSize: CGSize,
        contentMode: ContentMode,
        scale: CGFloat
    ) -> NSString {
        let pixelWidth = Int(targetSize.width * scale)
        let pixelHeight = Int(targetSize.height * scale)
        return "\(assetName)-\(pixelWidth)x\(pixelHeight)-\(contentMode == .fill ? "fill" : "fit")" as NSString
    }

    private static func drawingRect(for imageSize: CGSize, in bounds: CGRect, contentMode: ContentMode) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }

        let widthRatio = bounds.width / imageSize.width
        let heightRatio = bounds.height / imageSize.height
        let scale = contentMode == .fill ? max(widthRatio, heightRatio) : min(widthRatio, heightRatio)

        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: bounds.midX - (scaledSize.width / 2),
            y: bounds.midY - (scaledSize.height / 2)
        )

        return CGRect(origin: origin, size: scaledSize)
    }
}
