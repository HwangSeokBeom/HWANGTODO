import SwiftUI

/// A soft, consistent card surface used across every screen.
public struct CardSurface: ViewModifier {
    var padding: CGFloat

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
    }
}

public extension View {
    func cardSurface(padding: CGFloat = Theme.Spacing.m) -> some View {
        modifier(CardSurface(padding: padding))
    }
}

/// Uniform section header: title + optional trailing action.
public struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    public init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.Typography.sectionTitle)
            Spacer()
            trailing
        }
        .padding(.horizontal, Theme.Spacing.xs)
    }
}
