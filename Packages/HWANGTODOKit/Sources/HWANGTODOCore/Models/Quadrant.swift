import Foundation

/// The four Eisenhower quadrants plus an `unassigned` bucket for fast captures.
/// The Matrix is an *organization layer* applied after capture — never required
/// at capture time (spec §8).
///
/// Raw values are frozen: they live in the on-disk store, deep-link URLs, and
/// widget configurations.
nonisolated public enum Quadrant: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case urgentImportant
    case importantNotUrgent
    case urgentNotImportant
    case notUrgentNotImportant
    case unassigned

    public var id: String { rawValue }

    /// The four assignable quadrants, in canonical display order.
    public static let assignable: [Quadrant] = [
        .urgentImportant, .importantNotUrgent, .urgentNotImportant, .notUrgentNotImportant,
    ]

    /// Friendly quadrant name (spec §8's recommended vocabulary).
    public var title: String {
        switch self {
        case .urgentImportant: "지금 할 일"
        case .importantNotUrgent: "계획할 일"
        case .urgentNotImportant: "맡길 일"
        case .notUrgentNotImportant: "줄일 일"
        case .unassigned: "정리 전"
        }
    }

    /// The verb telling the user what to *do* with this quadrant (spec §8).
    public var actionLabel: String {
        switch self {
        case .urgentImportant: "지금 하기"
        case .importantNotUrgent: "일정 잡기"
        case .urgentNotImportant: "맡기기"
        case .notUrgentNotImportant: "줄이기"
        case .unassigned: "정리하기"
        }
    }

    /// The classic 급함×중요함 axis reading, shown as secondary text.
    public var axisDescription: String {
        switch self {
        case .urgentImportant: "급하고 중요함"
        case .importantNotUrgent: "중요하지만 급하지 않음"
        case .urgentNotImportant: "급하지만 덜 중요함"
        case .notUrgentNotImportant: "급하지도 중요하지도 않음"
        case .unassigned: "아직 정리하지 않음"
        }
    }

    /// Compact label for tight spaces (widgets, Live Activity).
    public var shortTitle: String {
        switch self {
        case .urgentImportant: "지금"
        case .importantNotUrgent: "계획"
        case .urgentNotImportant: "맡김"
        case .notUrgentNotImportant: "줄임"
        case .unassigned: "정리 전"
        }
    }

    public var symbol: String {
        switch self {
        case .urgentImportant: "bolt.fill"
        case .importantNotUrgent: "calendar"
        case .urgentNotImportant: "arrow.triangle.branch"
        case .notUrgentNotImportant: "arrow.down.right.circle"
        case .unassigned: "tray.and.arrow.down"
        }
    }
}
