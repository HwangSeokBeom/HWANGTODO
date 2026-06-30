import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Attributes for the "라이브 매트릭스" (Live Matrix) focus session. Shared so the app
/// can start/stop it and the widget extension can render it.
///
/// This is a GLANCEABLE FOCUS STATUS only — current focus task, quadrant, timer,
/// next action, and a progress count. It is NOT a task editor; iOS does not allow
/// arbitrary text input in a Live Activity / Dynamic Island.
#if canImport(ActivityKit)
struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var taskTitle: String
        var quadrantRaw: String
        var startedAt: Date
        var nextAction: String
        var doneCount: Int
        var totalCount: Int

        var quadrant: MatrixQuadrant { MatrixQuadrant(rawValue: quadrantRaw) ?? .unassigned }
        var progressText: String { "\(doneCount)/\(max(totalCount, 1))" }
    }

    var sessionName: String
}
#endif
