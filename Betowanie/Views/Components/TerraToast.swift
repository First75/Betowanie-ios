import SwiftUI

struct TerraToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.terraLabel())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.terraPrimary)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
    }
}
