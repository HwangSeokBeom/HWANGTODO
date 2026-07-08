import Foundation

/// Typed deep links. Widgets, notifications, Live Activities, and controls
/// build URLs from here; `AppRouter` parses them back. URL hosts are frozen —
/// they live inside placed widgets and scheduled notifications.
public nonisolated enum DeepLink: Equatable, Sendable {
    /// 기록 tab; optionally landing on the 완료한 일 segment.
    case captureHome(showCompleted: Bool = false)
    /// 정리 tab; optionally focused on one quadrant.
    case organize(quadrant: Quadrant? = nil)
    case schedule
    case routines
    case settings
    /// Quick-capture sheet with the keyboard up. The optional source records
    /// WHICH system surface opened it (제어센터 control, 잠금화면/홈 위젯 …) so
    /// the capture-source badge stays honest (spec §5).
    case capture(source: CaptureSource? = nil)
    /// 나와의 채팅 sheet.
    case chat
    /// 집중 sheet.
    case focus
    /// A specific task's detail.
    case task(UUID)

    // MARK: - URL building

    public var url: URL {
        var components = URLComponents()
        components.scheme = AppGroup.urlScheme
        switch self {
        case .captureHome(let showCompleted):
            components.host = "inbox"
            if showCompleted { components.queryItems = [URLQueryItem(name: "segment", value: "done")] }
        case .organize(let quadrant):
            if let quadrant {
                components.host = "quadrant"
                components.path = "/\(quadrant.rawValue)"
            } else {
                components.host = "matrix"
            }
        case .schedule: components.host = "calendar"
        case .routines: components.host = "routine"
        case .settings: components.host = "setup"
        case .capture(let source):
            components.host = "capture"
            if let source {
                components.queryItems = [URLQueryItem(name: "source", value: source.rawValue)]
            }
        case .chat: components.host = "chat"
        case .focus: components.host = "focus"
        case .task(let id):
            components.host = "task"
            components.path = "/\(id.uuidString)"
        }
        guard let url = components.url else {
            preconditionFailure("DeepLink produced an invalid URL for \(self)")
        }
        return url
    }

    // MARK: - Parsing

    public static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == AppGroup.urlScheme else { return nil }
        switch url.host {
        case "inbox":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let done = components?.queryItems?.contains { $0.name == "segment" && $0.value == "done" } ?? false
            return .captureHome(showCompleted: done)
        case "matrix": return .organize(quadrant: nil)
        case "quadrant":
            guard let raw = url.pathComponents.last, let quadrant = Quadrant(rawValue: raw) else {
                return .organize(quadrant: nil)
            }
            return .organize(quadrant: quadrant)
        case "calendar": return .schedule
        case "routine": return .routines
        case "setup": return .settings
        case "capture":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let raw = components?.queryItems?.first { $0.name == "source" }?.value
            return .capture(source: raw.flatMap(CaptureSource.init(rawValue:)))
        case "chat": return .chat
        case "focus": return .focus
        case "task":
            guard let raw = url.pathComponents.last, let id = UUID(uuidString: raw) else { return nil }
            return .task(id)
        default:
            return nil
        }
    }
}
