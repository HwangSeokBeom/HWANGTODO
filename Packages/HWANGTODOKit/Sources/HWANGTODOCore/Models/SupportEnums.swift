import Foundation

/// Lifecycle bucket. Fresh captures are `inbox` (정리 전); organized work is
/// `active`; `archived` items appear under 지난 기록. Raw values are frozen —
/// they live in the on-disk store.
nonisolated public enum TaskStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case inbox, active, done, archived

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .inbox: "정리 전"
        case .active: "진행 중"
        case .done: "완료한 일"
        case .archived: "지난 기록"
        }
    }
}

/// Optional priority — deliberately low-key so the app never nags.
nonisolated public enum TaskPriority: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case none, normal, high

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none: "없음"
        case .normal: "보통"
        case .high: "높음"
        }
    }
}

/// Where a task was captured from — surfaced as a small Korean badge (spec §5).
/// Raw values are frozen — they live in the on-disk store.
nonisolated public enum CaptureSource: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case app, shortcut, siri, actionButton, lockScreenWidget, homeWidget, controlCenter, notification, selfChat

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .app: "앱"
        case .shortcut: "단축어"
        case .siri: "Siri"
        case .actionButton: "액션 버튼"
        case .lockScreenWidget: "잠금화면"
        case .homeWidget: "홈 위젯"
        case .controlCenter: "제어센터"
        case .notification: "알림"
        case .selfChat: "채팅"
        }
    }

    public var symbol: String {
        switch self {
        case .app: "iphone"
        case .shortcut: "square.stack.3d.up"
        case .siri: "mic.fill"
        case .actionButton: "button.horizontal.top.press"
        case .lockScreenWidget: "lock.iphone"
        case .homeWidget: "rectangle.3.group"
        case .controlCenter: "switch.2"
        case .notification: "bell.fill"
        case .selfChat: "bubble.left.and.bubble.right"
        }
    }
}
