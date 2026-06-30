import SwiftUI

/// Whether a captured item is still undecided, a TODO, or a memo.
/// The distinction is deliberately made *after* capture, never at capture time.
enum ItemType: String, Codable, CaseIterable, Identifiable {
    case undecided, todo, memo
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .undecided: return "Undecided"
        case .todo: return "TODO"
        case .memo: return "Memo"
        }
    }
}

/// The lifecycle bucket an item currently lives in. Everything starts in `.inbox`.
enum ItemStatus: String, Codable, CaseIterable, Identifiable {
    case inbox, today, later, scheduled, done, archived
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .later: return "Later"
        case .scheduled: return "Scheduled"
        case .done: return "Done"
        case .archived: return "Archived"
        }
    }
}

/// Optional priority. Deliberately low-key visually so the app never nags.
enum ItemPriority: String, Codable, CaseIterable, Identifiable {
    case none, normal, high
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: return "None"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }
    var accentColor: Color? {
        switch self {
        case .none: return nil
        case .normal: return .blue
        case .high: return .orange // calm, not aggressive red
        }
    }
}
