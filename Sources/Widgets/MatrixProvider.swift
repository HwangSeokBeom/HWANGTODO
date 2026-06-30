import WidgetKit
import SwiftUI

/// Snapshot of the shared store for the widgets.
struct MatrixEntry: TimelineEntry {
    let date: Date
    let counts: [MatrixQuadrant: Int]
    let inboxCount: Int
    let todayCount: Int
    let urgentCount: Int
    let nextTask: String?

    var urgentImportant: Int { counts[.urgentImportant] ?? 0 }
    var importantNotUrgent: Int { counts[.importantNotUrgent] ?? 0 }
    var urgentNotImportant: Int { counts[.urgentNotImportant] ?? 0 }
    var notUrgentNotImportant: Int { counts[.notUrgentNotImportant] ?? 0 }

    static let placeholder = MatrixEntry(
        date: .now,
        counts: [.urgentImportant: 2, .importantNotUrgent: 3, .urgentNotImportant: 1, .notUrgentNotImportant: 1],
        inboxCount: 2, todayCount: 3, urgentCount: 2,
        nextTask: "TokenForge 레이아웃 이슈 확인")
}

/// Reads the SAME App Group store the app and AppIntents write to.
struct MatrixProvider: TimelineProvider {
    func placeholder(in context: Context) -> MatrixEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (MatrixEntry) -> Void) {
        completion(context.isPreview ? .placeholder : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MatrixEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [current()], policy: .after(next)))
    }

    private func current() -> MatrixEntry {
        let store = TaskStore.shared
        return MatrixEntry(
            date: .now,
            counts: store.quadrantCounts(),
            inboxCount: store.inboxCount,
            todayCount: store.todayCount(),
            urgentCount: store.urgentCount,
            nextTask: store.nextTask()?.title)
    }
}
