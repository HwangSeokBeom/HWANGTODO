import Foundation

/// The single shared persistence layer, backed by JSON files inside the App
/// Group container. The app, the widget extension, AppIntents, and the Live
/// Activity all talk to THIS store, so a task captured from any system surface
/// shows up everywhere — one source of truth, no split-brain.
final class TaskStore {
    static let shared = TaskStore()

    private let tasksFile = "hwangtodo_tasks.json"
    private let chatFile = "hwangtodo_chat.json"
    private let routinesFile = "hwangtodo_routines.json"
    private let queue = DispatchQueue(label: "com.hwangtodo.store", attributes: .concurrent)

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
    }
    private var baseURL: URL {
        containerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private lazy var encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    private init() {}

    private func load<T: Decodable>(_ file: String, as type: [T].Type) -> [T] {
        queue.sync {
            let url = baseURL.appendingPathComponent(file)
            guard let data = try? Data(contentsOf: url),
                  let items = try? decoder.decode([T].self, from: data) else { return [] }
            return items
        }
    }

    private func save<T: Encodable>(_ items: [T], to file: String) {
        queue.sync(flags: .barrier) {
            let url = baseURL.appendingPathComponent(file)
            guard let data = try? encoder.encode(items) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Tasks

    func loadTasks() -> [MatrixTask] { load(tasksFile, as: [MatrixTask].self) }
    func saveTasks(_ items: [MatrixTask]) { save(items, to: tasksFile) }

    /// Append a freshly captured task. Used by AppIntents and quick capture.
    @discardableResult
    func addTask(title: String, quadrant: MatrixQuadrant = .unassigned,
                 dueDate: Date? = nil, memo: String? = nil, source: CaptureSource = .app) -> MatrixTask {
        let status: TaskStatus = quadrant == .unassigned ? .inbox : .active
        let task = MatrixTask(title: title, body: memo, status: status, quadrant: quadrant,
                              dueDate: dueDate, source: source)
        var items = loadTasks()
        items.append(task)
        saveTasks(items)
        return task
    }

    /// Marks the most recently created OPEN task as done (used by notification actions).
    func completeLatestOpenTask() {
        var items = loadTasks()
        guard let idx = items.enumerated()
            .filter({ $0.element.isOpen })
            .max(by: { $0.element.createdAt < $1.element.createdAt })?.offset else { return }
        items[idx].status = .done
        items[idx].completedAt = .now
        items[idx].updatedAt = .now
        saveTasks(items)
    }

    // MARK: - Chat

    func loadChat() -> [ChatMessage] { load(chatFile, as: [ChatMessage].self) }
    func saveChat(_ items: [ChatMessage]) { save(items, to: chatFile) }
    @discardableResult
    func addChatMessage(_ text: String) -> ChatMessage {
        let message = ChatMessage(text: text)
        var items = loadChat(); items.append(message); saveChat(items)
        return message
    }

    // MARK: - Routines

    func loadRoutines() -> [Routine] { load(routinesFile, as: [Routine].self) }
    func saveRoutines(_ items: [Routine]) { save(items, to: routinesFile) }

    // MARK: - Derived values for widgets / glances

    func quadrantCounts() -> [MatrixQuadrant: Int] {
        var counts: [MatrixQuadrant: Int] = [:]
        for task in loadTasks() where task.isOpen { counts[task.quadrant, default: 0] += 1 }
        return counts
    }

    var inboxCount: Int { loadTasks().filter { $0.status == .inbox }.count }

    var urgentCount: Int { loadTasks().filter { $0.isOpen && $0.quadrant == .urgentImportant }.count }

    /// Open tasks due today + active routines scheduled today (excluding done).
    func todayCount(calendar: Calendar = .current) -> Int {
        let dueToday = loadTasks().filter {
            $0.isOpen && ($0.dueDate.map { calendar.isDateInToday($0) } ?? false)
        }.count
        let routinesToday = loadRoutines().filter {
            $0.isScheduled(on: .now, calendar: calendar) && !$0.isCompleted(on: .now, calendar: calendar)
        }.count
        return dueToday + routinesToday
    }

    func topTasks(in quadrant: MatrixQuadrant, limit: Int) -> [MatrixTask] {
        loadTasks()
            .filter { $0.quadrant == quadrant && $0.isOpen }
            .sorted { ($0.isPinned ? 1 : 0, $0.createdAt) > ($1.isPinned ? 1 : 0, $1.createdAt) }
            .prefix(limit).map { $0 }
    }

    /// The single most relevant "next" task for glance surfaces.
    func nextTask() -> MatrixTask? {
        topTasks(in: .urgentImportant, limit: 1).first
            ?? topTasks(in: .importantNotUrgent, limit: 1).first
            ?? loadTasks().filter { $0.status == .inbox }.sorted { $0.createdAt > $1.createdAt }.first
    }
}
