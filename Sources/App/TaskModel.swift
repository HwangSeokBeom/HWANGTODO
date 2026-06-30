import SwiftUI
import Observation
import WidgetKit

/// In-memory, observable cache over the shared `TaskStore`. Every mutation writes
/// through to the App Group store and reloads widget timelines, so the app,
/// widgets, AppIntents, and the Live Activity never disagree.
@MainActor
@Observable
final class TaskModel {
    private(set) var tasks: [MatrixTask] = []
    private(set) var chat: [ChatMessage] = []
    private(set) var routines: [Routine] = []

    init() { reload() }

    func reload() {
        tasks = TaskStore.shared.loadTasks()
        chat = TaskStore.shared.loadChat()
        routines = TaskStore.shared.loadRoutines()
    }

    // MARK: - Task queries

    var inbox: [MatrixTask] {
        tasks.filter { $0.status == .inbox }
            .sorted { ($0.isPinned ? 1 : 0, $0.createdAt) > ($1.isPinned ? 1 : 0, $1.createdAt) }
    }

    func tasks(in quadrant: MatrixQuadrant) -> [MatrixTask] {
        tasks.filter { $0.quadrant == quadrant && $0.isOpen }
            .sorted { ($0.isPinned ? 1 : 0, $0.createdAt) > ($1.isPinned ? 1 : 0, $1.createdAt) }
    }
    func count(in quadrant: MatrixQuadrant) -> Int { tasks(in: quadrant).count }

    func todayTasks(calendar: Calendar = .current) -> [MatrixTask] {
        tasks.filter { $0.isOpen && ($0.dueDate.map { calendar.isDateInToday($0) } ?? false) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    func overdueTasks(calendar: Calendar = .current) -> [MatrixTask] {
        tasks.filter { $0.isOpen && ($0.dueDate.map { $0 < calendar.startOfDay(for: .now) } ?? false) }
    }
    func upcomingTasks(calendar: Calendar = .current) -> [MatrixTask] {
        let tomorrow = calendar.startOfDay(for: .now).addingTimeInterval(86400)
        return tasks.filter { $0.isOpen && ($0.dueDate.map { $0 >= tomorrow } ?? false) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    var scheduledTasks: [MatrixTask] {
        tasks.filter { $0.isOpen && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    var archived: [MatrixTask] {
        tasks.filter { $0.status == .archived }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }
    func nextFocusTask() -> MatrixTask? {
        tasks(in: .urgentImportant).first ?? tasks(in: .importantNotUrgent).first
    }
    func task(with id: UUID) -> MatrixTask? { tasks.first { $0.id == id } }

    // MARK: - Daily progress (todo mate–style clarity)

    /// Open + done counts for today's one-off tasks and routines combined.
    func dailyProgress(calendar: Calendar = .current) -> (done: Int, total: Int) {
        let dueToday = tasks.filter { $0.dueDate.map { calendar.isDateInToday($0) } ?? false }
        let doneTasks = dueToday.filter { $0.status == .done }.count
        let routinesToday = todayRoutines
        let doneRoutines = routinesToday.filter { $0.isCompleted(on: .now) }.count
        return (doneTasks + doneRoutines, dueToday.count + routinesToday.count)
    }

    // MARK: - Task mutations

    @discardableResult
    func capture(_ title: String, source: CaptureSource = .app,
                 quadrant: MatrixQuadrant = .unassigned, memo: String? = nil) -> MatrixTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let status: TaskStatus = quadrant == .unassigned ? .inbox : .active
        let task = MatrixTask(title: trimmed, body: memo, status: status, quadrant: quadrant, source: source)
        tasks.append(task)
        persist()
        return task
    }

    func update(_ task: MatrixTask) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i] = task; persist()
    }
    func assign(_ task: MatrixTask, to quadrant: MatrixQuadrant) {
        mutate(task) { $0.quadrant = quadrant; $0.status = quadrant == .unassigned ? .inbox : .active; $0.updatedAt = .now }
    }
    func markDone(_ task: MatrixTask) {
        mutate(task) { $0.status = .done; $0.completedAt = $0.completedAt ?? .now; $0.updatedAt = .now }
    }
    func moveToToday(_ task: MatrixTask) {
        mutate(task) { $0.dueDate = Calendar.current.startOfDay(for: .now).addingTimeInterval(9*3600); $0.status = .active; $0.updatedAt = .now }
    }
    func archive(_ task: MatrixTask) {
        mutate(task) { $0.status = .archived; $0.archivedAt = $0.archivedAt ?? .now; $0.updatedAt = .now }
    }
    func restore(_ task: MatrixTask) {
        mutate(task) { $0.status = $0.quadrant == .unassigned ? .inbox : .active; $0.completedAt = nil; $0.archivedAt = nil; $0.updatedAt = .now }
    }
    func delete(_ task: MatrixTask) {
        NotificationManager.shared.cancelReminder(id: task.id)
        tasks.removeAll { $0.id == task.id }; persist()
    }

    /// Convert a one-off task into a daily routine.
    func convertToRoutine(_ task: MatrixTask) {
        let routine = Routine(title: task.title, weekdays: [], defaultQuadrant: task.quadrant == .unassigned ? nil : task.quadrant)
        routines.append(routine)
        tasks.removeAll { $0.id == task.id }
        TaskStore.shared.saveRoutines(routines)
        persist()
    }

    // MARK: - Chat

    @discardableResult
    func sendChat(_ text: String) -> ChatMessage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let message = ChatMessage(text: trimmed)
        chat.append(message); persistChat()
        return message
    }
    func convertChatMessage(_ message: ChatMessage, into titles: [String]) {
        var created: [UUID] = []
        for title in titles { if let task = capture(title, source: .selfChat) { created.append(task.id) } }
        guard let i = chat.firstIndex(where: { $0.id == message.id }) else { return }
        chat[i].convertedTaskIDs.append(contentsOf: created); persistChat()
    }

    // MARK: - Routines

    var todayRoutines: [Routine] {
        routines.filter { $0.isScheduled(on: .now) }
    }
    func addRoutine(title: String, weekdays: [Int], defaultQuadrant: MatrixQuadrant?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        routines.append(Routine(title: trimmed, weekdays: weekdays, defaultQuadrant: defaultQuadrant))
        persistRoutines()
    }
    func toggleRoutine(_ routine: Routine, on date: Date = .now) {
        guard let i = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        let day = Calendar.current.startOfDay(for: date)
        if let idx = routines[i].completionDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: day) }) {
            routines[i].completionDates.remove(at: idx)
        } else {
            routines[i].completionDates.append(day)
        }
        persistRoutines()
    }
    func deleteRoutine(_ routine: Routine) {
        routines.removeAll { $0.id == routine.id }; persistRoutines()
    }

    func resetSampleData() {
        SampleDataSeeder.reset(); reload(); WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Helpers

    private func mutate(_ task: MatrixTask, _ change: (inout MatrixTask) -> Void) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        change(&tasks[i]); persist()
    }
    private func persist() { TaskStore.shared.saveTasks(tasks); WidgetCenter.shared.reloadAllTimelines() }
    private func persistChat() { TaskStore.shared.saveChat(chat) }
    private func persistRoutines() { TaskStore.shared.saveRoutines(routines); WidgetCenter.shared.reloadAllTimelines() }
}
