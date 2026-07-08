import Foundation
import SwiftData

/// The single core entity: one captured thing to do.
///
/// Enum-typed fields are stored as raw strings (`statusRaw` …) so that an old
/// build reading a store written by a newer build degrades gracefully instead
/// of failing to decode. Use the typed accessors (`status` …) everywhere.
@Model
public final class TodoItem {
    @Attribute(.unique) public var id: UUID
    public var title: String
    /// 내부 메모 (spec §11).
    public var note: String?
    /// 외부 메모 링크 — e.g. an Apple Notes URL the user pasted (spec §11).
    public var noteLinkURL: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var statusRaw: String
    public var quadrantRaw: String
    public var priorityRaw: String
    public var dueDate: Date?
    public var reminderDate: Date?
    /// EventKit identifier of the linked calendar event (spec §9).
    public var calendarEventID: String?
    public var sourceRaw: String
    public var isPinned: Bool
    public var completedAt: Date?
    public var archivedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        note: String? = nil,
        noteLinkURL: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        status: TaskStatus = .inbox,
        quadrant: Quadrant = .unassigned,
        priority: TaskPriority = .none,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        calendarEventID: String? = nil,
        source: CaptureSource = .app,
        isPinned: Bool = false,
        completedAt: Date? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.noteLinkURL = noteLinkURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        statusRaw = status.rawValue
        quadrantRaw = quadrant.rawValue
        priorityRaw = priority.rawValue
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.calendarEventID = calendarEventID
        sourceRaw = source.rawValue
        self.isPinned = isPinned
        self.completedAt = completedAt
        self.archivedAt = archivedAt
    }

    // MARK: - Typed accessors

    public var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .inbox }
        set { statusRaw = newValue.rawValue }
    }

    public var quadrant: Quadrant {
        get { Quadrant(rawValue: quadrantRaw) ?? .unassigned }
        set { quadrantRaw = newValue.rawValue }
    }

    public var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    public var source: CaptureSource {
        get { CaptureSource(rawValue: sourceRaw) ?? .app }
        set { sourceRaw = newValue.rawValue }
    }

    // MARK: - Convenience

    public var hasNote: Bool { note?.isEmpty == false || noteLinkURL?.isEmpty == false }
    public var hasCalendarEvent: Bool { calendarEventID?.isEmpty == false }
    public var isOpen: Bool { status == .inbox || status == .active }
}

public extension TodoItem {
    /// Canonical ordering for lists and widgets: pinned first, newest first.
    nonisolated static func displayOrder(_ a: (isPinned: Bool, createdAt: Date), _ b: (isPinned: Bool, createdAt: Date)) -> Bool {
        if a.isPinned != b.isPinned { return a.isPinned }
        return a.createdAt > b.createdAt
    }
}

public extension [TodoItem] {
    /// Pinned first, newest first — the app's one canonical list order.
    func displaySorted() -> [TodoItem] {
        sorted { TodoItem.displayOrder(($0.isPinned, $0.createdAt), ($1.isPinned, $1.createdAt)) }
    }
}
