import SwiftUI

struct TerraButton: View {
    enum Style {
        case primary
        case secondary
        case destructive
    }

    let title: String
    var style: Style = .primary
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                }
                Text(title)
                    .font(.terraLabel())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if style == .secondary {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.terraPrimary, lineWidth: 1)
                }
            }
        }
        .disabled(isLoading)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return Color.terraPrimary
        case .secondary: return Color.terraCardFill
        case .destructive: return Color.terraError.opacity(0.1)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return Color.terraPrimary
        case .destructive: return Color.terraError
        }
    }
}
