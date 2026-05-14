import SwiftUI

// MARK: - Terra Color Palette

extension Color {
    static let terraPrimary = Color(red: 74/255, green: 124/255, blue: 89/255)       // #4a7c59 Forest green
    static let terraBackground = Color(red: 250/255, green: 246/255, blue: 240/255)   // #faf6f0 Warm cream
    static let terraTertiary = Color(red: 112/255, green: 92/255, blue: 48/255)       // #705c30 Warm amber
    static let terraCardFill = Color(red: 242/255, green: 236/255, blue: 226/255)     // #f2ece2 Deeper cream
    static let terraTextPrimary = Color(red: 46/255, green: 50/255, blue: 48/255)     // #2e3230 Near-black
    static let terraTextSecondary = Color(red: 107/255, green: 107/255, blue: 94/255) // #6b6b5e Warm grey
    static let terraError = Color(red: 180/255, green: 60/255, blue: 50/255)          // Warm red
    static let terraSuccess = Color(red: 74/255, green: 124/255, blue: 89/255)        // Same as primary
}

// MARK: - Terra Typography

extension Font {
    static func terraHeadline(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }

    static func terraTitle(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func terraBody(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func terraCaption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func terraLabel(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}
