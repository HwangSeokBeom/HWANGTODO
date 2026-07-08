import ActivityKit
import Foundation
import HWANGTODOCore
import Observation
import OSLog

/// Drives one 집중 session: an ordered task queue, the 집중 화면, and the
/// Live Matrix Live Activity (spec §7).
///
/// The Live Activity is only ever requested/updated/ended from this manager
/// (app process). The widget process cannot repaint it — its buttons write to
/// the shared store (완료) or shared defaults (다음), and `attach(repository:)`
/// reconciles both on every foreground.
@MainActor
@Observable
final class FocusSessionManager {
    static let shared = FocusSessionManager()

    /// Shared-defaults key the widget-process 다음 button writes.
    /// Must match `Sources/Widgets/FocusLiveActivity.swift`.
    private static let pendingSkipKey = "focus.pendingSkipTaskID"

    private let log = Logger(subsystem: "com.hwangtodo.app", category: "FocusSession")

    private(set) var isActive = false
    private(set) var currentTaskID: UUID?
    /// Session start — the Live Activity and 집중 화면 render elapsed time from it.
    private(set) var startedAt = Date.now
    /// Session queue in start order; completions are derived from the store,
    /// never counted twice.
    private var queueIDs: [UUID] = []

    @ObservationIgnored private var repository: TodoRepository?
    @ObservationIgnored private var activity: Activity<FocusActivityAttributes>?
    @ObservationIgnored private var hookedRepository: ObjectIdentifier?
    /// Reentrancy guard: `completeCurrent()` advances itself, so the
    /// repository completion hook must not advance a second time.
    @ObservationIgnored private var isMutatingInternally = false

    private init() {}

    // MARK: - Derived state

    var totalCount: Int { queueIDs.count }

    /// Done count read from the store, so a 완료 from the Live Activity
    /// (widget process) or any other screen is reflected without bookkeeping.
    var doneCount: Int {
        guard let repository else { return 0 }
        return queueIDs.count { repository.task(withID: $0)?.status == .done }
    }

    var currentTask: TodoItem? {
        guard let currentTaskID else { return nil }
        return repository?.task(withID: currentTaskID)
    }

    /// The next still-open task after the current one, if any.
    var nextTask: TodoItem? { openTask(after: currentTaskID) }

    /// Position label, e.g. "2/4".
    var progressLabel: String {
        guard totalCount > 0 else { return "0/0" }
        return "\(min(doneCount + 1, totalCount))/\(totalCount)"
    }

    /// 0…1 completion fraction for progress rings.
    var progress: Double {
        totalCount > 0 ? Double(doneCount) / Double(totalCount) : 0
    }

    /// Whether iOS allows Live Activities right now (설정에서 끌 수 있음).
    var activitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    // MARK: - Wiring

    /// Idempotent. Called at every foreground: stores the repository, chains
    /// into the completion hook, applies widget-process signals (완료 written
    /// to the store, 다음 written to shared defaults), and refreshes or ends
    /// the Live Activity to match.
    func attach(repository: TodoRepository) {
        self.repository = repository
        installCompletionHook(on: repository)
        guard isActive else {
            endOrphanedActivities()
            return
        }
        applyPendingSkip()
        if let currentTaskID, repository.task(withID: currentTaskID)?.isOpen != true {
            // Completed (or removed) from another process/screen while backgrounded.
            advanceToNextOpen(after: currentTaskID)
        } else if activity != nil {
            updateActivity()
        } else if activitiesEnabled {
            // The session outlived its activity (started from a notification
            // action before activation, or ActivityKit rejected a background
            // request). Replace any stale lock-screen leftovers and retry.
            endOrphanedActivities()
            requestActivity()
        }
    }

    // MARK: - Session control

    /// Starts a session over the open tasks in `queue` and requests the Live
    /// Activity. A previous session's activity is replaced.
    func start(queue: [TodoItem]) {
        let open = queue.filter(\.isOpen)
        guard !open.isEmpty else { return }
        endCurrentActivity()
        AppGroup.defaults.removeObject(forKey: Self.pendingSkipKey)
        queueIDs = open.map(\.id)
        currentTaskID = queueIDs.first
        startedAt = .now
        isActive = true
        requestActivity()
        if !activitiesEnabled {
            // 집중 알림 (spec §6.7): without Live Activities, a notification is
            // the only surface saying a session is running.
            NotificationManager.shared.notifyFocusSession(taskTitle: open[0].title)
        }
        log.info("focus session started: \(open.count) tasks")
    }

    /// Marks the current task done and moves on (or ends when it was the last).
    func completeCurrent() {
        guard isActive, let repository, let currentTaskID else { return }
        if let item = repository.task(withID: currentTaskID), item.isOpen {
            isMutatingInternally = true
            repository.markDone(item)
            isMutatingInternally = false
        }
        advanceToNextOpen(after: currentTaskID)
    }

    /// Skips the current task (stays open in its quadrant) and moves on.
    func advance() {
        guard isActive, let currentTaskID else { return }
        advanceToNextOpen(after: currentTaskID)
    }

    /// Ends the session and removes the Live Activity immediately.
    func end() {
        isActive = false
        currentTaskID = nil
        queueIDs = []
        AppGroup.defaults.removeObject(forKey: Self.pendingSkipKey)
        endCurrentActivity()
        NotificationManager.shared.clearFocusSessionNotification()
    }

    // MARK: - Queue internals

    private func advanceToNextOpen(after id: UUID) {
        guard let next = openTask(after: id) else {
            end()
            return
        }
        currentTaskID = next.id
        updateActivity()
    }

    private func openTask(after id: UUID?) -> TodoItem? {
        guard let repository, let id, let index = queueIDs.firstIndex(of: id) else { return nil }
        for candidate in queueIDs.dropFirst(index + 1) {
            if let item = repository.task(withID: candidate), item.isOpen {
                return item
            }
        }
        return nil
    }

    /// Chains behind any previously installed hooks so other subsystems
    /// (알림 등) keep receiving completions/removals.
    private func installCompletionHook(on repository: TodoRepository) {
        let identifier = ObjectIdentifier(repository)
        guard hookedRepository != identifier else { return }
        hookedRepository = identifier
        let previousCompleted = repository.hooks.taskCompleted
        repository.hooks.taskCompleted = { [weak self] item in
            previousCompleted(item)
            self?.taskCompletedElsewhere(item)
        }
        let previousRemoved = repository.hooks.taskRemoved
        repository.hooks.taskRemoved = { [weak self] id in
            previousRemoved(id)
            self?.taskRemovedElsewhere(id)
        }
    }

    /// A queued task was deleted (or converted to a routine) mid-session —
    /// the lock screen must never keep showing a task that no longer exists,
    /// and a removed task must not linger in the progress denominator.
    private func taskRemovedElsewhere(_ id: UUID) {
        guard isActive, queueIDs.contains(id) else { return }
        if id == currentTaskID {
            let next = openTask(after: id)
            queueIDs.removeAll { $0 == id }
            if let next {
                currentTaskID = next.id
                updateActivity()
            } else {
                end()
            }
        } else {
            queueIDs.removeAll { $0 == id }
            updateActivity()
        }
    }

    /// A queued task was completed outside `completeCurrent()` (task detail,
    /// 알림 액션, …) while the app is in the foreground.
    private func taskCompletedElsewhere(_ item: TodoItem) {
        guard isActive, !isMutatingInternally, queueIDs.contains(item.id) else { return }
        if item.id == currentTaskID {
            advanceToNextOpen(after: item.id)
        } else {
            updateActivity()
        }
    }

    /// Applies a 다음 request made from the Live Activity buttons (widget
    /// process writes shared defaults; only the app can move the queue).
    private func applyPendingSkip() {
        let defaults = AppGroup.defaults
        guard let raw = defaults.string(forKey: Self.pendingSkipKey) else { return }
        defaults.removeObject(forKey: Self.pendingSkipKey)
        guard let id = UUID(uuidString: raw), id == currentTaskID else { return }
        advanceToNextOpen(after: id)
    }

    // MARK: - Live Activity

    private func currentContent() -> FocusActivityAttributes.ContentState? {
        guard let task = currentTask else { return nil }
        return FocusActivityAttributes.ContentState(
            taskID: task.id,
            title: task.title,
            quadrantRaw: task.quadrant.rawValue,
            startedAt: startedAt,
            doneCount: doneCount,
            totalCount: totalCount,
            nextTitle: nextTask?.title
        )
    }

    private func requestActivity() {
        guard activitiesEnabled else {
            log.notice("Live Activity disabled by user setting; session runs in-app only")
            return
        }
        guard let content = currentContent() else {
            log.notice("activity request skipped: no current content (repository not attached yet?)")
            return
        }
        do {
            activity = try Activity.request(
                attributes: FocusActivityAttributes(),
                content: ActivityContent(state: content, staleDate: nil)
            )
        } catch {
            log.error("Live Activity request failed: \(error, privacy: .public)")
        }
    }

    private func updateActivity() {
        guard let activity, let content = currentContent() else { return }
        let box = ActivityBox(value: activity)
        Task {
            await box.update(ActivityContent(state: content, staleDate: nil))
        }
    }

    private func endCurrentActivity() {
        guard let activity else { return }
        self.activity = nil
        let box = ActivityBox(value: activity)
        Task {
            await box.end()
        }
    }

    /// The app was relaunched while an old session's activity was still on the
    /// lock screen. The in-memory queue is gone, so the honest move is to
    /// remove the stale activity instead of showing dead buttons.
    private func endOrphanedActivities() {
        guard activity == nil else { return }
        let orphans = Activity<FocusActivityAttributes>.activities.map(ActivityBox.init(value:))
        guard !orphans.isEmpty else { return }
        log.notice("ending \(orphans.count) orphaned focus activities")
        Task {
            for orphan in orphans {
                await orphan.end()
            }
        }
    }
}

/// `Activity` is not Sendable in the iOS 26 SDK, but its async methods are
/// documented-safe to call from any context. The unchecked box keeps the
/// calls inside one audited type instead of scattering unsafe annotations.
private struct ActivityBox: @unchecked Sendable {
    nonisolated(unsafe) let value: Activity<FocusActivityAttributes>

    func update(_ content: ActivityContent<FocusActivityAttributes.ContentState>) async {
        await value.update(content)
    }

    func end() async {
        await value.end(nil, dismissalPolicy: .immediate)
    }
}
