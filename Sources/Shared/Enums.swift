import SwiftUI

/// The four Eisenhower quadrants plus an `unassigned` bucket for fast captures.
/// The Matrix is an *organization layer* applied after capture — never required
/// at capture time.
enum MatrixQuadrant: String, Codable, CaseIterable, Identifiable, Hashable {
    case urgentImportant
    case importantNotUrgent
    case urgentNotImportant
    case notUrgentNotImportant
    case unassigned

    var id: String { rawValue }

    static var assignable: [MatrixQuadrant] {
        [.urgentImportant, .importantNotUrgent, .urgentNotImportant, .notUrgentNotImportant]
    }

    /// Korean quadrant name.
    var title: String {
        switch self {
        case .urgentImportant: return "급하고 중요함"
        case .importantNotUrgent: return "중요하지만 급하지 않음"
        case .urgentNotImportant: return "급하지만 덜 중요함"
        case .notUrgentNotImportant: return "줄이기 / 제거하기"
        case .unassigned: return "정리 전"
        }
    }

    /// The short verb telling the user what to *do* with this quadrant.
    var actionLabel: String {
        switch self {
        case .urgentImportant: return "지금 하기"
        case .importantNotUrgent: return "일정 잡기"
        case .urgentNotImportant: return "맡기기"
        case .notUrgentNotImportant: return "줄이기"
        case .unassigned: return "정리하기"
        }
    }

    /// Compact label for tight spaces (widgets, Live Activity).
    var shortTitle: String {
        switch self {
        case .urgentImportant: return "급함·중요"
        case .importantNotUrgent: return "중요"
        case .urgentNotImportant: return "급함"
        case .notUrgentNotImportant: return "줄이기"
        case .unassigned: return "정리 전"
        }
    }

    var symbol: String {
        switch self {
        case .urgentImportant: return "bolt.fill"
        case .importantNotUrgent: return "calendar"
        case .urgentNotImportant: return "arrow.triangle.branch"
        case .notUrgentNotImportant: return "tray"
        case .unassigned: return "circle.dotted"
        }
    }

    /// Subtle, desaturated accents — typography leads, color supports.
    var accent: Color {
        switch self {
        case .urgentImportant: return Color(red: 0.83, green: 0.34, blue: 0.30)
        case .importantNotUrgent: return Color(red: 0.27, green: 0.46, blue: 0.78)
        case .urgentNotImportant: return Color(red: 0.78, green: 0.56, blue: 0.24)
        case .notUrgentNotImportant: return Color(red: 0.46, green: 0.49, blue: 0.53)
        case .unassigned: return Color(red: 0.46, green: 0.49, blue: 0.53)
        }
    }
}

/// Lifecycle bucket. Fresh captures are `inbox`; organized work is `active`.
enum TaskStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case inbox, active, done, archived
    var id: String { rawValue }
}

enum MatrixPriority: String, Codable, CaseIterable, Identifiable, Hashable {
    case none, normal, high
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: return "없음"
        case .normal: return "보통"
        case .high: return "높음"
        }
    }
}

/// Where a task was captured from — surfaced as a small Korean badge.
enum CaptureSource: String, Codable, CaseIterable, Identifiable, Hashable {
    case app, shortcut, siri, actionButton, lockScreenWidget, homeWidget, controlCenter, notification, selfChat
    var id: String { rawValue }

    var label: String {
        switch self {
        case .app: return "앱"
        case .shortcut: return "단축어"
        case .siri: return "Siri"
        case .actionButton: return "액션 버튼"
        case .lockScreenWidget: return "잠금화면"
        case .homeWidget: return "홈 위젯"
        case .controlCenter: return "제어센터"
        case .notification: return "알림"
        case .selfChat: return "채팅"
        }
    }

    var symbol: String {
        switch self {
        case .app: return "iphone"
        case .shortcut: return "square.stack.3d.up"
        case .siri: return "mic.fill"
        case .actionButton: return "button.horizontal.top.press"
        case .lockScreenWidget: return "lock.iphone"
        case .homeWidget: return "rectangle.3.group"
        case .controlCenter: return "switch.2"
        case .notification: return "bell.fill"
        case .selfChat: return "bubble.left.and.bubble.right"
        }
    }
}
