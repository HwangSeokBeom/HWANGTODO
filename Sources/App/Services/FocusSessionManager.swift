import Foundation
import Observation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Starts/stops the "라이브 매트릭스" focus session (Live Activity). Honest scope: it
/// shows a glanceable focus status — current task, quadrant, timer, next action,
/// and a progress count. It is NOT a task editor (no text input in a Live Activity
/// / Dynamic Island).
@MainActor
@Observable
final class FocusSessionManager {
    static let shared = FocusSessionManager()

    var activeTaskTitle: String?
    var isRunning: Bool = false

    private init() {}

    var isSupported: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) { return ActivityAuthorizationInfo().areActivitiesEnabled }
        #endif
        return false
    }

    /// Start focusing on `task`. Progress is the done/total of today's "지금 하기" work.
    func start(task: MatrixTask, in model: TaskModel) {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            endAll()
            let urgent = model.tasks(in: .urgentImportant)
            let total = max(urgent.count, 1)
            let done = model.tasks.filter { $0.quadrant == .urgentImportant && $0.status == .done }.count
            let attributes = FocusActivityAttributes(sessionName: "라이브 매트릭스")
            let state = FocusActivityAttributes.ContentState(
                taskTitle: task.title,
                quadrantRaw: task.quadrant.rawValue,
                startedAt: .now,
                nextAction: task.quadrant.actionLabel,
                doneCount: done,
                totalCount: total)
            do {
                _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
                activeTaskTitle = task.title
                isRunning = true
            } catch { isRunning = false }
        }
        #endif
    }

    func stop() {
        endAll(); isRunning = false; activeTaskTitle = nil
    }

    private func endAll() {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            for activity in Activity<FocusActivityAttributes>.activities {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
        }
        #endif
    }

    func refresh() {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            let activities = Activity<FocusActivityAttributes>.activities
            isRunning = !activities.isEmpty
            activeTaskTitle = activities.first?.content.state.taskTitle
        }
        #endif
    }
}
