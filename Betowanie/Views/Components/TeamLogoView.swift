import SwiftUI

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

    var body: some View {
        if let localAssetName, UIImage(named: localAssetName) != nil {
            Image(localAssetName)
                .resizable()
                .aspectRatio(contentMode: contentMode)
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
