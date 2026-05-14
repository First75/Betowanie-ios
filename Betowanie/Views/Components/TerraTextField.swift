import SwiftUI

struct TerraTextField: View {
    let title: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.terraCaption())
                .foregroundStyle(Color.terraTextSecondary)

            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .font(.terraBody())
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.terraCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ? Color.terraPrimary : Color.clear,
                        lineWidth: 2
                    )
            }
            .focused($isFocused)
        }
    }
}
