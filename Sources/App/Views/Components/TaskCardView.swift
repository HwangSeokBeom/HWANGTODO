import HWANGTODOCore
import HWANGTODODesign
import SwiftData
import SwiftUI

/// Reusable task card: title + capture-source badge + organize/schedule
/// indicators (spec §5 출처 배지). Deliberately action-free — swipe and context
/// actions belong to the owning list, so the card renders identically on the
/// 기록 홈, 정리, and 일정 screens.
struct TaskCardView: View {
    let item: TodoItem

    init(item: TodoItem) {
        self.item = item
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(Color.hwangAccent)
                        .accessibilityLabel("고정됨")
                }
                Text(item.title)
                    .font(Theme.Typography.cardTitle)
                    .strikethrough(item.status == .done)
                    .foregroundStyle(item.status == .done ? Color.secondary : Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            HStack(spacing: Theme.Spacing.xs) {
                SourceBadge(item.source)
                if item.quadrant != .unassigned {
                    QuadrantTag(item.quadrant, compact: true)
                }
                dueIndicator
                if item.reminderDate != nil {
                    indicator("bell", accessibility: "알림 있음")
                }
                if item.hasCalendarEvent {
                    indicator("calendar", accessibility: "캘린더에 연결됨")
                }
                if item.hasNote {
                    indicator("note.text", accessibility: "메모 있음")
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    /// 오늘/내일은 말로, 그 외는 날짜로. 지난 기한만 조용히 붉게 표시.
    @ViewBuilder private var dueIndicator: some View {
        if let dueDate = item.dueDate {
            Label(Self.dueText(for: dueDate), systemImage: "clock")
                .font(Theme.Typography.badge)
                .foregroundStyle(isOverdue ? Color.red : Color.secondary)
        }
    }

    private var isOverdue: Bool {
        guard let dueDate = item.dueDate, item.isOpen else { return false }
        return dueDate < Calendar.current.startOfDay(for: .now)
    }

    private static func dueText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "오늘" }
        if calendar.isDateInTomorrow(date) { return "내일" }
        return date.formatted(.dateTime.month().day())
    }

    private func indicator(_ symbol: String, accessibility label: String) -> some View {
        Image(systemName: symbol)
            .font(Theme.Typography.badge)
            .foregroundStyle(.secondary)
            .accessibilityLabel(label)
    }
}

#if DEBUG
#Preview("작업 카드") {
    ScrollView {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(TaskCardPreviewData.items) { item in
                TaskCardView(item: item)
            }
        }
        .padding(Theme.Spacing.m)
    }
    .background(Theme.screenBackground)
    .modelContainer(TaskCardPreviewData.container)
}

/// In-memory samples covering every indicator combination the card renders.
private enum TaskCardPreviewData {
    static let container: ModelContainer = {
        // swiftlint:disable:next force_try
        try! ModelContainer(
            for: SharedStore.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }()

    static let items: [TodoItem] = {
        let calendar = Calendar.current
        let today9 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: .now)
        let overdue = calendar.date(byAdding: .day, value: -2, to: .now)
        let samples = [
            TodoItem(title: "은행 서류 제출", source: .siri, isPinned: true),
            TodoItem(
                title: "회의 자료 마무리",
                note: "슬라이드 3장 남음",
                status: .active,
                quadrant: .urgentImportant,
                dueDate: today9,
                calendarEventID: "preview-event",
                source: .homeWidget
            ),
            TodoItem(
                title: "책 반납하기",
                status: .active,
                quadrant: .urgentNotImportant,
                dueDate: overdue,
                reminderDate: .now,
                source: .actionButton
            ),
            TodoItem(title: "어제 회의록 공유", status: .done, source: .selfChat, completedAt: .now),
        ]
        samples.forEach(container.mainContext.insert)
        try? container.mainContext.save()
        return samples
    }()
}
#endif
