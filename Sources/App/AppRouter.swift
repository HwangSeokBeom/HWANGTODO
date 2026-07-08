import Foundation
import HWANGTODOCore
import Observation

/// Routes deep links (widgets, notifications, controls, Siri) to the right
/// tab/sheet/task. The 기록 home is the landing surface — capture first,
/// organize later.
@MainActor
@Observable
final class AppRouter {
    /// The live router, for AppIntents running in the app process
    /// (open-and-navigate intents). Set once at app startup.
    static var current: AppRouter?

    enum Tab: Hashable { case capture, organize, schedule, routine, settings }

    enum Sheet: String, Identifiable {
        case capture, chat, focus
        var id: String { rawValue }
    }

    var selectedTab: Tab = .capture
    var presentedSheet: Sheet?
    /// Task detail requested by a deep link (notification tap, Live Activity).
    var presentedTaskID: UUID?
    /// 기록 home segment: false = 정리 전, true = 완료한 일.
    var showCompleted = false
    /// Quadrant to drill into on the 정리 tab.
    var focusedQuadrant: Quadrant?
    /// Bumped to move keyboard focus into the quick-capture field.
    var captureFocusToken = 0
    /// The system surface that opened the capture sheet (제어센터 컨트롤,
    /// 잠금화면/홈 위젯 …) — consumed by CaptureSheetView so the source badge
    /// stays honest. Cleared when the sheet closes.
    var pendingCaptureSource: CaptureSource?

    func handle(url: URL) {
        guard let link = DeepLink.parse(url) else { return }
        navigate(to: link)
    }

    func navigate(to link: DeepLink) {
        // Tab-level routes dismiss any sheet so the destination is visible.
        switch link {
        case .captureHome(let showCompleted):
            presentedSheet = nil
            selectedTab = .capture
            self.showCompleted = showCompleted
        case .organize(let quadrant):
            presentedSheet = nil
            selectedTab = .organize
            focusedQuadrant = quadrant
        case .schedule:
            presentedSheet = nil
            selectedTab = .schedule
        case .routines:
            presentedSheet = nil
            selectedTab = .routine
        case .settings:
            presentedSheet = nil
            selectedTab = .settings
        case .capture(let source):
            pendingCaptureSource = source
            presentedSheet = .capture
            captureFocusToken += 1
        case .chat:
            presentedSheet = .chat
        case .focus:
            presentedSheet = .focus
        case .task(let id):
            presentedSheet = nil
            presentedTaskID = id
        }
    }
}
