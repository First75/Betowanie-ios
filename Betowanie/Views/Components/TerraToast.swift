import SwiftUI

// MARK: - Toast Center

/// App-wide toast center. Call `Toast.shared.show("...", style: .positive)` from anywhere.
/// The active toast is rendered by `.toastHost()` applied near the root of the view tree.
@Observable
@MainActor
final class Toast {
    static let shared = Toast()

    enum Style {
        case positive
        case negative
        case warning
    }

    struct Item: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let style: Style
    }

    private(set) var current: Item?

    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ message: String, style: Style = .positive, duration: TimeInterval = 2.0) {
        dismissTask?.cancel()
        current = Item(message: message, style: style)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

// MARK: - Toast View

private struct TerraToastBubble: View {
    let item: Toast.Item

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.style.iconName)
                .foregroundStyle(.white)
            Text(item.message)
                .font(.terraLabel())
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(item.style.backgroundColor)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 16)
    }
}

private extension Toast.Style {
    var iconName: String {
        switch self {
        case .positive: return "checkmark.circle.fill"
        case .negative: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .positive: return Color.terraPrimary
        case .negative: return Color.terraError
        case .warning: return Color.terraTertiary
        }
    }
}

// MARK: - Host Modifier

private struct ToastHostModifier: ViewModifier {
    @State private var toast = Toast.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let item = toast.current {
                    TerraToastBubble(item: item)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .id(item.id)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: toast.current?.id)
    }
}

extension View {
    /// Overlays the global toast above this view. Apply once, near the root.
    func toastHost() -> some View {
        modifier(ToastHostModifier())
    }
}
