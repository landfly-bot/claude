import SwiftUI

enum Theme {
    static let brand = Color(red: 0.18, green: 0.50, blue: 0.93)
    static let brandLight = Color(red: 0.34, green: 0.80, blue: 0.95)

    static let water = LinearGradient(
        colors: [brandLight, brand],
        startPoint: .top,
        endPoint: .bottom
    )

    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
}

/// 统一的卡片外观
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}
