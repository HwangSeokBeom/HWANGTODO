import SwiftUI
import Observation

/// Routes deep links (widgets, notifications, Control Center, Siri) to the right
/// tab/sheet. The Quick Inbox is the home — capture-first, organize later.
@Observable
final class AppRouter {
    enum Tab: Hashable { case inbox, matrix, calendar, routine, setup }
    enum Sheet: String, Identifiable { case capture, chat, focus; var id: String { rawValue } }

    var selectedTab: Tab = .inbox
    var focusedQuadrant: MatrixQuadrant?
    var presentedSheet: Sheet?
    var captureFocusToken = 0

    func handle(url: URL) {
        guard url.scheme == AppGroup.urlScheme else { return }
        switch url.host {
        case "inbox": selectedTab = .inbox
        case "matrix": selectedTab = .matrix
        case "calendar": selectedTab = .calendar
        case "routine": selectedTab = .routine
        case "setup": selectedTab = .setup
        case "capture":
            presentedSheet = .capture
            captureFocusToken += 1
        case "chat": presentedSheet = .chat
        case "focus": presentedSheet = .focus
        case "quadrant":
            selectedTab = .matrix
            focusedQuadrant = MatrixQuadrant(rawValue: url.pathComponents.last ?? "")
        default:
            break
        }
    }
}
