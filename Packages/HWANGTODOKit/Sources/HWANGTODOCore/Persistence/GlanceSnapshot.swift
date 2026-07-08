import Foundation
import SwiftData

/// Sendable value snapshot of "everything a glance surface needs" — widget
/// timelines, the Live Activity, and lock-screen entries render from this so
/// they never hold live model objects.
public nonisolated struct GlanceSnapshot: Sendable, Hashable {
    public struct TaskSummary: Sendable, Hashable, Identifiable {
        public let id: UUID
        public let title: String
        public let quadrant: Quadrant
        public let isDueToday: Bool
        public let hasCalendarEvent: Bool

        public init(id: UUID, title: String, quadrant: Quadrant, isDueToday: Bool, hasCalendarEvent: Bool) {
            self.id = id
            self.title = title
            self.quadrant = quadrant
            self.isDueToday = isDueToday
            self.hasCalendarEvent = hasCalendarEvent
        }
    }

    public let date: Date
    /// Open-task count per quadrant (unassigned = 정리 전).
    public let quadrantCounts: [Quadrant: Int]
    /// Top open tasks per quadrant, canonical order, max 3 each.
    public let topTasks: [Quadrant: [TaskSummary]]
    public let inboxCount: Int
    public let urgentCount: Int
    /// 오늘 할 일: open tasks due today + routines scheduled today, not yet done.
    public let todayOpenCount: Int
    /// Tasks + routines completed today (완료감).
    public let todayDoneCount: Int
    public let routineTodayTotal: Int
    public let routineTodayDone: Int
    /// The single most relevant next task.
    public let nextTask: TaskSummary?
    /// Open tasks due today that are linked to a calendar event.
    public let calendarLinkedToday: [TaskSummary]

    public init(
        date: Date,
        quadrantCounts: [Quadrant: Int],
        topTasks: [Quadrant: [TaskSummary]],
        inboxCount: Int,
        urgentCount: Int,
        todayOpenCount: Int,
        todayDoneCount: Int,
        routineTodayTotal: Int,
        routineTodayDone: Int,
        nextTask: TaskSummary?,
        calendarLinkedToday: [TaskSummary]
    ) {
        self.date = date
        self.quadrantCounts = quadrantCounts
        self.topTasks = topTasks
        self.inboxCount = inboxCount
        self.urgentCount = urgentCount
        self.todayOpenCount = todayOpenCount
        self.todayDoneCount = todayDoneCount
        self.routineTodayTotal = routineTodayTotal
        self.routineTodayDone = routineTodayDone
        self.nextTask = nextTask
        self.calendarLinkedToday = calendarLinkedToday
    }

    public var routineProgress: Double {
        routineTodayTotal > 0 ? Double(routineTodayDone) / Double(routineTodayTotal) : 0
    }

    /// Placeholder content for widget galleries and previews.
    public static let placeholder = GlanceSnapshot(
        date: .now,
        quadrantCounts: [.urgentImportant: 2, .importantNotUrgent: 3, .urgentNotImportant: 1, .notUrgentNotImportant: 1, .unassigned: 2],
        topTasks: [
            .urgentImportant: [TaskSummary(id: UUID(), title: "회의 자료 마무리", quadrant: .urgentImportant, isDueToday: true, hasCalendarEvent: true)],
            .importantNotUrgent: [TaskSummary(id: UUID(), title: "운동 계획 세우기", quadrant: .importantNotUrgent, isDueToday: false, hasCalendarEvent: false)],
        ],
        inboxCount: 2,
        urgentCount: 2,
        todayOpenCount: 4,
        todayDoneCount: 3,
        routineTodayTotal: 3,
        routineTodayDone: 2,
        nextTask: TaskSummary(id: UUID(), title: "회의 자료 마무리", quadrant: .urgentImportant, isDueToday: true, hasCalendarEvent: true),
        calendarLinkedToday: []
    )
}

public extension GlanceSnapshot {
    /// Builds a snapshot from the shared store. MainActor: widget timeline
    /// providers call it with `await`.
    @MainActor
    static func make(
        context: ModelContext = SharedStore.context,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> GlanceSnapshot {
        let openDescriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.statusRaw == "inbox" || $0.statusRaw == "active" }
        )
        let open = ((try? context.fetch(openDescriptor)) ?? []).displaySorted()

        let doneRaw = TaskStatus.done.rawValue
        let doneDescriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.statusRaw == doneRaw })
        let done = (try? context.fetch(doneDescriptor)) ?? []

        let routines = ((try? context.fetch(FetchDescriptor<Routine>())) ?? [])
            .filter { $0.isScheduled(on: now, calendar: calendar) }

        var counts: [Quadrant: Int] = [:]
        var top: [Quadrant: [TaskSummary]] = [:]
        for item in open {
            counts[item.quadrant, default: 0] += 1
            if top[item.quadrant, default: []].count < 3 {
                top[item.quadrant, default: []].append(summary(of: item, calendar: calendar, now: now))
            }
        }

        let dueToday = open.filter { $0.dueDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false }
        let doneToday = done.filter { $0.completedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false }
        let routinesDone = routines.filter { $0.isCompleted(on: now, calendar: calendar) }

        let next = open.first { $0.quadrant == .urgentImportant }
            ?? open.first { $0.quadrant == .importantNotUrgent }
            ?? open.first { $0.status == .inbox }

        return GlanceSnapshot(
            date: now,
            quadrantCounts: counts,
            topTasks: top,
            inboxCount: open.count(where: { $0.status == .inbox }),
            urgentCount: counts[.urgentImportant] ?? 0,
            todayOpenCount: dueToday.count + (routines.count - routinesDone.count),
            todayDoneCount: doneToday.count + routinesDone.count,
            routineTodayTotal: routines.count,
            routineTodayDone: routinesDone.count,
            nextTask: next.map { summary(of: $0, calendar: calendar, now: now) },
            calendarLinkedToday: dueToday.filter(\.hasCalendarEvent).prefix(3).map { summary(of: $0, calendar: calendar, now: now) }
        )
    }

    @MainActor
    private static func summary(of item: TodoItem, calendar: Calendar, now: Date) -> TaskSummary {
        TaskSummary(
            id: item.id,
            title: item.title,
            quadrant: item.quadrant,
            isDueToday: item.dueDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false,
            hasCalendarEvent: item.hasCalendarEvent
        )
    }
}
