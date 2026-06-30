import Foundation

/// The single core entity. Named `MatrixTask` (not `Task`) to avoid colliding
/// with Swift Concurrency's `Task`. A plain `Codable` struct so it can be shared
/// across the app, the widget extension, and AppIntents via one App Group store.
struct MatrixTask: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var body: String?
    var createdAt: Date
    var updatedAt: Date
    var statusRaw: String
    var quadrantRaw: String
    var priorityRaw: String
    var dueDate: Date?
    var reminderDate: Date?
    var calendarEventIdentifier: String?
    var noteLinkURL: String?
    var sourceRaw: String
    var tags: [String]
    var isPinned: Bool
    var completedAt: Date?
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        body: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        status: TaskStatus = .inbox,
        quadrant: MatrixQuadrant = .unassigned,
        priority: MatrixPriority = .none,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        calendarEventIdentifier: String? = nil,
        noteLinkURL: String? = nil,
        source: CaptureSource = .app,
        tags: [String] = [],
        isPinned: Bool = false,
        completedAt: Date? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.statusRaw = status.rawValue
        self.quadrantRaw = quadrant.rawValue
        self.priorityRaw = priority.rawValue
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.calendarEventIdentifier = calendarEventIdentifier
        self.noteLinkURL = noteLinkURL
        self.sourceRaw = source.rawValue
        self.tags = tags
        self.isPinned = isPinned
        self.completedAt = completedAt
        self.archivedAt = archivedAt
    }

    // MARK: - Enum bridges

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .inbox }
        set { statusRaw = newValue.rawValue }
    }
    var quadrant: MatrixQuadrant {
        get { MatrixQuadrant(rawValue: quadrantRaw) ?? .unassigned }
        set { quadrantRaw = newValue.rawValue }
    }
    var priority: MatrixPriority {
        get { MatrixPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }
    var source: CaptureSource {
        get { CaptureSource(rawValue: sourceRaw) ?? .app }
        set { sourceRaw = newValue.rawValue }
    }

    // MARK: - Convenience

    var hasNote: Bool { (noteLinkURL?.isEmpty == false) || (body?.isEmpty == false) }
    var hasCalendarEvent: Bool { calendarEventIdentifier?.isEmpty == false }
    var isOpen: Bool { status == .inbox || status == .active }
}
