import Foundation
import OSLog
import SwiftData
import WidgetKit

/// The one read/write surface for app UI, AppIntents, and notification
/// handlers, on top of the shared SwiftData store.
///
/// It keeps observable in-memory arrays (`items`, `routines`, `chatEntries`)
/// that views render directly. Every mutation writes through to the store,
/// reloads the arrays, and refreshes widget timelines — so the app, widgets,
/// intents, and the Live Activity never disagree. `reload()` runs on every
/// foreground to pick up writes from the widget process.
@MainActor
@Observable
public final class TodoRepository {
    /// Fired after mutations that other app subsystems react to
    /// (notifications, Live Activity). Wired once at app startup.
    public struct Hooks {
        public var taskCompleted: (TodoItem) -> Void = { _ in }
        public var taskRemoved: (UUID) -> Void = { _ in }
        public var reminderChanged: (TodoItem) -> Void = { _ in }
        public init() {}
    }

    let log = Logger(subsystem: "com.hwangtodo.app", category: "TodoRepository")
    public let context: ModelContext
    @ObservationIgnored public var hooks = Hooks()

    /// All tasks, canonical order (pinned first, newest first).
    public private(set) var items: [TodoItem] = []
    public private(set) var routines: [Routine] = []
    /// 나와의 채팅, oldest first.
    public private(set) var chatEntries: [ChatEntry] = []

    /// Keeps an owned container alive: `ModelContext` does NOT retain its
    /// container, so a repository built over a locally created container
    /// (tests, previews) would otherwise trap on the first save.
    @ObservationIgnored private let retainedContainer: ModelContainer?

    public init(context: ModelContext = SharedStore.context) {
        self.context = context
        retainedContainer = nil
        reload()
    }

    /// Owns `container` for its lifetime — use for in-memory test/preview
    /// stacks where nothing else retains the container.
    public init(container: ModelContainer) {
        context = container.mainContext
        retainedContainer = container
        reload()
    }

    /// Re-fetches everything from the store. Called on init, after every
    /// mutation, and on app foreground (widget-process writes land here).
    public func reload() {
        items = ((try? context.fetch(FetchDescriptor<TodoItem>())) ?? []).displaySorted()
        routines = (try? context.fetch(FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        chatEntries = (try? context.fetch(FetchDescriptor<ChatEntry>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    // MARK: - Task queries (over the observable arrays)

    public var inbox: [TodoItem] { items.filter { $0.status == .inbox } }
    public var completed: [TodoItem] {
        items.filter { $0.status == .done }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    public var archived: [TodoItem] {
        items.filter { $0.status == .archived }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    public var openItems: [TodoItem] { items.filter(\.isOpen) }

    public func tasks(in quadrant: Quadrant) -> [TodoItem] {
        items.filter { $0.quadrant == quadrant && $0.isOpen }
    }

    public func count(in quadrant: Quadrant) -> Int { tasks(in: quadrant).count }

    public func task(withID id: UUID) -> TodoItem? { items.first { $0.id == id } }

    public func todayTasks(calendar: Calendar = .current) -> [TodoItem] {
        openItems.filter { $0.dueDate.map { calendar.isDateInToday($0) } ?? false }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    public func overdueTasks(calendar: Calendar = .current) -> [TodoItem] {
        let dayStart = calendar.startOfDay(for: .now)
        return openItems.filter { $0.dueDate.map { $0 < dayStart } ?? false }
            .sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
    }

    public func upcomingTasks(calendar: Calendar = .current) -> [TodoItem] {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) else { return [] }
        return openItems.filter { $0.dueDate.map { $0 >= tomorrow } ?? false }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    public var scheduledTasks: [TodoItem] {
        openItems.filter { $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    public func completedToday(calendar: Calendar = .current) -> Int {
        items.count { $0.status == .done && ($0.completedAt.map { calendar.isDateInToday($0) } ?? false) }
    }

    /// 오늘의 진행률 (todo mate-style). Denominator: tasks due today (open or
    /// done, archived excluded) + routines scheduled today. Numerator: those
    /// already done. One definition, used by home, widgets, and 일정 alike.
    public func dailyProgress(calendar: Calendar = .current) -> (done: Int, total: Int) {
        let dueToday = items.filter {
            $0.status != .archived && ($0.dueDate.map { calendar.isDateInToday($0) } ?? false)
        }
        let doneTasks = dueToday.count { $0.status == .done }
        let scheduledRoutines = todayRoutines
        let doneRoutines = scheduledRoutines.count { $0.isCompleted(on: .now, calendar: calendar) }
        return (doneTasks + doneRoutines, dueToday.count + scheduledRoutines.count)
    }

    /// The most relevant "next" task: 지금 할 일 first, then 계획할 일, then
    /// the freshest 정리 전 capture.
    public func nextTask() -> TodoItem? {
        tasks(in: .urgentImportant).first
            ?? tasks(in: .importantNotUrgent).first
            ?? inbox.first
    }

    /// The 집중 queue: 지금 할 일, pinned first.
    public var focusQueue: [TodoItem] { tasks(in: .urgentImportant) }

    // MARK: - Capture (the product's core promise)

    /// Records a task in 정리 전 (or straight into a quadrant when given).
    /// Returns nil for effectively-empty titles.
    @discardableResult
    public func capture(
        _ title: String,
        source: CaptureSource = .app,
        quadrant: Quadrant = .unassigned,
        dueDate: Date? = nil,
        note: String? = nil
    ) -> TodoItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let item = TodoItem(
            title: trimmed,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            status: quadrant == .unassigned ? .inbox : .active,
            quadrant: quadrant,
            dueDate: dueDate,
            source: source
        )
        context.insert(item)
        persist()
        return item
    }

    // MARK: - Task mutations

    public func markDone(_ item: TodoItem) {
        item.status = .done
        item.completedAt = item.completedAt ?? .now
        touch(item)
        hooks.taskCompleted(item)
    }

    public func reopen(_ item: TodoItem) {
        item.status = item.quadrant == .unassigned ? .inbox : .active
        item.completedAt = nil
        item.archivedAt = nil
        touch(item)
        // Re-arm the reminder that completing/archiving cancelled — otherwise
        // the detail screen shows an 알림 that will never fire.
        hooks.reminderChanged(item)
    }

    public func assign(_ item: TodoItem, to quadrant: Quadrant) {
        item.quadrant = quadrant
        if item.isOpen {
            item.status = quadrant == .unassigned ? .inbox : .active
        }
        touch(item)
    }

    public func moveToToday(_ item: TodoItem, hour: Int = 9, calendar: Calendar = .current) {
        item.dueDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: .now)
        if item.status == .inbox { item.status = .active }
        touch(item)
    }

    public func schedule(_ item: TodoItem, at date: Date?) {
        item.dueDate = date
        if date != nil, item.status == .inbox { item.status = .active }
        touch(item)
    }

    public func setReminder(_ item: TodoItem, at date: Date?) {
        item.reminderDate = date
        touch(item)
        hooks.reminderChanged(item)
    }

    public func togglePin(_ item: TodoItem) {
        item.isPinned.toggle()
        touch(item)
    }

    public func setPriority(_ item: TodoItem, _ priority: TaskPriority) {
        item.priority = priority
        touch(item)
    }

    public func setTitle(_ item: TodoItem, _ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        item.title = trimmed
        touch(item)
    }

    public func setNote(_ item: TodoItem, text: String?, linkURL: String?) {
        item.note = text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        item.noteLinkURL = linkURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        touch(item)
    }

    public func linkCalendarEvent(_ item: TodoItem, eventID: String?) {
        item.calendarEventID = eventID
        touch(item)
    }

    public func archive(_ item: TodoItem) {
        item.status = .archived
        item.archivedAt = item.archivedAt ?? .now
        touch(item)
        // An archived task must not notify: the scheduler's isOpen guard
        // turns this into a cancellation.
        hooks.reminderChanged(item)
    }

    public func delete(_ item: TodoItem) {
        let id = item.id
        context.delete(item)
        persist()
        hooks.taskRemoved(id)
    }

    /// Converts a task into a routine, carrying over what makes sense.
    /// The source task is removed (it lives on as the routine).
    @discardableResult
    public func convertToRoutine(_ item: TodoItem, weekdays: [Int] = []) -> Routine {
        let routine = Routine(
            title: item.title,
            weekdays: weekdays,
            defaultQuadrant: item.quadrant == .unassigned ? nil : item.quadrant
        )
        context.insert(routine)
        let id = item.id
        context.delete(item)
        persist()
        hooks.taskRemoved(id)
        return routine
    }

    // MARK: - Routines

    public var todayRoutines: [Routine] { routines.filter { $0.isScheduled(on: .now) } }

    public var activeRoutines: [Routine] { routines.filter(\.isActive) }

    public func routine(withID id: UUID) -> Routine? { routines.first { $0.id == id } }

    @discardableResult
    public func addRoutine(
        title: String,
        weekdays: [Int] = [],
        defaultQuadrant: Quadrant? = nil,
        reminderMinutes: Int? = nil
    ) -> Routine? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let routine = Routine(
            title: trimmed,
            weekdays: weekdays,
            defaultQuadrant: defaultQuadrant,
            reminderMinutes: reminderMinutes
        )
        context.insert(routine)
        persist()
        return routine
    }

    public func toggleRoutineCompletion(_ routine: Routine, on date: Date = .now) {
        routine.toggleCompletion(on: date)
        persist()
    }

    public func setRoutineActive(_ routine: Routine, _ active: Bool) {
        routine.isActive = active
        persist()
    }

    public func updateRoutine(
        _ routine: Routine,
        title: String? = nil,
        weekdays: [Int]? = nil,
        defaultQuadrant: Quadrant?? = nil,
        reminderMinutes: Int?? = nil
    ) {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            routine.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let weekdays { routine.weekdays = weekdays.sorted() }
        if let defaultQuadrant { routine.defaultQuadrant = defaultQuadrant }
        if let reminderMinutes { routine.reminderMinutes = reminderMinutes }
        persist()
    }

    public func deleteRoutine(_ routine: Routine) {
        context.delete(routine)
        persist()
    }

    // MARK: - 나와의 채팅

    @discardableResult
    public func addChatEntry(_ text: String) -> ChatEntry? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let entry = ChatEntry(text: trimmed)
        context.insert(entry)
        persist()
        return entry
    }

    /// Creates tasks from selected candidate titles. Titles already converted
    /// from this entry are skipped, so re-converting never duplicates — the
    /// dedup key is the title AS CONVERTED (`convertedTitles`), so renaming or
    /// deleting the created task later cannot reopen the hole. Entries from
    /// before `convertedTitles` existed fall back to the surviving tasks'
    /// current titles.
    @discardableResult
    public func convert(_ entry: ChatEntry, titles: [String]) -> [TodoItem] {
        var alreadyConverted = Set(entry.titlesConvertedSoFar)
        if alreadyConverted.isEmpty {
            alreadyConverted.formUnion(entry.convertedTaskIDs.compactMap { id in task(withID: id)?.title })
        }
        var created: [TodoItem] = []
        var recordedTitles = entry.titlesConvertedSoFar
        for title in titles {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !alreadyConverted.contains(trimmed) else { continue }
            if let item = capture(trimmed, source: .selfChat) {
                created.append(item)
                alreadyConverted.insert(trimmed)
                recordedTitles.append(trimmed)
            }
        }
        entry.convertedTitles = recordedTitles
        entry.convertedTaskIDs.append(contentsOf: created.map(\.id))
        persist()
        return created
    }

    public func deleteChatEntry(_ entry: ChatEntry) {
        context.delete(entry)
        persist()
    }

    // MARK: - Internals

    func touch(_ item: TodoItem) {
        item.updatedAt = .now
        persist()
    }

    func persist() {
        do {
            try context.save()
        } catch {
            log.error("save failed: \(error, privacy: .public)")
            assertionFailure("SwiftData save failed: \(error)")
        }
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
