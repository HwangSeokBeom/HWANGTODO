import HWANGTODOCore
import HWANGTODODesign
import SwiftUI

/// One cell of the 정리 2×2 grid (spec §8): quadrant name, the 급함×중요함 axis
/// reading, the open count, and the representative task. Deliberately
/// render-only — navigation belongs to `MatrixView`, so the card previews and
/// tests without a repository.
struct QuadrantCard: View {
    let quadrant: Quadrant
    let openCount: Int
    /// The quadrant's representative task (spec §8 "각 분면의 대표 할 일").
    let topTaskTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: quadrant.symbol)
                    .font(Theme.Typography.badge)
                Text(quadrant.title)
                    .font(Theme.Typography.cardTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .foregroundStyle(quadrant.accent)

            Text(quadrant.axisDescription)
                .font(Theme.Typography.badge)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: Theme.Spacing.s)

            Text("\(openCount)")
                .font(Theme.Typography.number)
                .foregroundStyle(openCount > 0 ? Color.primary : Color.secondary)

            Text(topTaskTitle ?? "비어 있어요")
                .font(Theme.Typography.meta)
                .foregroundStyle(topTaskTitle == nil ? Color.secondary.opacity(0.6) : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var summary = "\(quadrant.title), \(quadrant.axisDescription), \(openCount)개"
        if let topTaskTitle {
            summary += ", 대표 할 일 \(topTaskTitle)"
        }
        return summary
    }
}

#if DEBUG
#Preview("분면 카드") {
    LazyVGrid(
        columns: [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible(), spacing: Theme.Spacing.s)],
        spacing: Theme.Spacing.s
    ) {
        QuadrantCard(quadrant: .urgentImportant, openCount: 2, topTaskTitle: "회의 자료 마무리")
        QuadrantCard(quadrant: .importantNotUrgent, openCount: 3, topTaskTitle: "운동 계획 세우기")
        QuadrantCard(quadrant: .urgentNotImportant, openCount: 1, topTaskTitle: "우편물 발송 맡기기")
        QuadrantCard(quadrant: .notUrgentNotImportant, openCount: 0, topTaskTitle: nil)
    }
    .padding(Theme.Spacing.m)
    .background(Theme.screenBackground)
}
#endif
