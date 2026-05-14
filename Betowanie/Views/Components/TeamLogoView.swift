import SwiftUI
import WebKit

struct TeamLogoView: View {
    let urlString: String
    let teamName: String
    var size: CGFloat = 36

    var body: some View {
        if urlString.lowercased().hasSuffix(".svg") {
            SVGWebView(urlString: urlString, size: size)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            AsyncImage(url: URL(string: urlString)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    initialsView
                default:
                    ProgressView()
                        .frame(width: size, height: size)
                }
            }
            .frame(width: size, height: size)
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
struct SVGWebView: UIViewRepresentable {
    let urlString: String
    let size: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else { return }
        // Use an HTML wrapper to ensure the SVG fits the view bounds and has transparent background
        let html = """
        <html>
        <head>
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">
            <style>
                html, body { margin:0; padding:0; background: transparent; }
                img { width: 100%; height: 100%; object-fit: contain; display:block; }
            </style>
        </head>
        <body>
            <img src=\"\(url.absoluteString)\" alt=\"team\" />
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

