import SwiftUI

/// Central design tokens. Minimal, Apple-native, restrained Liquid Glass:
/// typography and spacing carry the hierarchy; color supports, never shouts
/// (spec §15).
public enum Theme {
    public enum Spacing {
        public static let xs: CGFloat = 6
        public static let s: CGFloat = 10
        public static let m: CGFloat = 16
        public static let l: CGFloat = 24
        public static let xl: CGFloat = 32
    }

    public enum Radius {
        public static let card: CGFloat = 20
        public static let chip: CGFloat = 12
        public static let small: CGFloat = 10
    }

    /// Typography tokens on top of Dynamic Type styles — never fixed sizes.
    public enum Typography {
        /// Screen hero title (빠른 기록).
        public static let hero = Font.largeTitle.weight(.bold)
        public static let sectionTitle = Font.title3.weight(.semibold)
        public static let cardTitle = Font.body.weight(.medium)
        public static let meta = Font.footnote
        public static let badge = Font.caption2.weight(.medium)
        public static let number = Font.title2.weight(.bold).monospacedDigit()
    }

    public static let cardBackground = Color(.secondarySystemGroupedBackground)
    public static let screenBackground = Color(.systemGroupedBackground)
    public static let hairline = Color(.separator).opacity(0.5)
}

public extension Animation {
    /// The app's one standard spring for state changes.
    static var hwangSnappy: Animation { .snappy(duration: 0.28) }
}
