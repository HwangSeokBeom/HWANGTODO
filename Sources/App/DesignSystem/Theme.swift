import SwiftUI

/// Central design tokens. Minimal, Apple-native, premium light UI.
/// Typography and spacing carry the hierarchy; color is used sparingly.
enum Theme {
    enum Spacing {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        /// Bottom inset so scroll content never hides behind the tab bar.
        static let tabBarBottomInset: CGFloat = 96
    }

    enum Radius {
        static let card: CGFloat = 18
        static let chip: CGFloat = 12
        static let small: CGFloat = 10
    }

    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let screenBackground = Color(.systemGroupedBackground)
    static let hairline = Color(.separator).opacity(0.5)
}

/// A soft, consistent card surface used across every screen.
struct CardSurface: ViewModifier {
    var padding: CGFloat = Theme.Spacing.m
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
    }
}

extension View {
    func cardSurface(padding: CGFloat = Theme.Spacing.m) -> some View {
        modifier(CardSurface(padding: padding))
    }

    /// Standard bottom padding so content clears the tab bar without clipping.
    func tabBarSafeBottomPadding() -> some View {
        safeAreaInset(edge: .bottom) { Color.clear.frame(height: Theme.Spacing.tabBarBottomInset) }
    }
}
