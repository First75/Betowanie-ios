import SwiftUI

// MARK: - Card Style

struct TerraCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.terraCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: Color(red: 0.18, green: 0.20, blue: 0.19).opacity(0.06),
                radius: 20, x: 0, y: 4
            )
    }
}

extension View {
    func terraCard() -> some View {
        modifier(TerraCardModifier())
    }
}
