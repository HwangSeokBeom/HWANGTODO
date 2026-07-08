#if DEBUG
import Foundation
import SwiftData

/// Demo data for screenshots and simulator QA. NEVER runs automatically —
/// production first launch starts empty (spec §15: no sample-app feel).
/// Trigger via the hidden developer row in 설정, or the `-hwangtodo-seed-demo`
/// launch argument.
@MainActor
public enum DebugSeeder {
    public static let launchArgument = "-hwangtodo-seed-demo"

    /// Inserts a small, realistic Korean data set. Idempotent-ish: skips when
    /// the store already has any task.
    public static func seed(into context: ModelContext = SharedStore.context) {
        let existing = (try? context.fetchCount(FetchDescriptor<TodoItem>())) ?? 0
        guard existing == 0 else { return }

        let calendar = Calendar.current
        let today9 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: .now)

        let items: [TodoItem] = [
            TodoItem(title: "회의 자료 마무리", status: .active, quadrant: .urgentImportant, dueDate: today9, source: .app, isPinned: true),
            TodoItem(title: "은행 서류 제출", status: .active, quadrant: .urgentImportant, dueDate: today9, source: .siri),
            TodoItem(title: "운동 계획 세우기", status: .active, quadrant: .importantNotUrgent, source: .homeWidget),
            TodoItem(title: "책 반납하기", status: .active, quadrant: .urgentNotImportant, source: .actionButton),
            TodoItem(title: "메일함 비우기", status: .active, quadrant: .notUrgentNotImportant, source: .app),
            TodoItem(title: "엄마한테 전화하기", source: .selfChat),
            TodoItem(title: "장보기 목록 만들기", source: .controlCenter),
            TodoItem(title: "어제 회의록 공유", status: .done, source: .app, completedAt: .now),
        ]
        items.forEach(context.insert)

        let routines: [Routine] = [
            Routine(title: "물 마시기"),
            Routine(title: "운동하기", weekdays: [2, 4, 6]),
            Routine(title: "업무일지 작성", weekdays: [2, 3, 4, 5, 6], defaultQuadrant: .importantNotUrgent),
        ]
        routines.forEach(context.insert)
        routines.first?.toggleCompletion(on: .now)

        context.insert(ChatEntry(text: "오늘 업무일지 쓰고, 캘린더 확인하고, 엄마한테 전화해야 함"))

        try? context.save()
    }

    /// Removes everything. Debug-only escape hatch behind its own confirm UI.
    public static func wipeAll(context: ModelContext = SharedStore.context) {
        try? context.delete(model: TodoItem.self)
        try? context.delete(model: Routine.self)
        try? context.delete(model: ChatEntry.self)
        try? context.save()
    }
}
#endif
