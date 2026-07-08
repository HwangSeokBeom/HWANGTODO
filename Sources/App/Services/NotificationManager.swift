import Foundation
import HWANGTODOCore
import OSLog
import UserNotifications

/// 알림 파이프라인 (spec §6.7): 할 일 알림, 루틴 알림, 하루 점검 알림과
/// 잠금화면 알림 액션(완료/나중에/오늘로 이동/집중 시작/열기).
///
/// Reliability rules:
/// - The `UNUserNotificationCenter` delegate is installed synchronously in
///   `bootstrap` (called from `App.init`) so cold-start action taps land.
/// - Actions resolve their task strictly by UUID — a stale notification for a
///   deleted task logs and does nothing; it never touches another task.
/// - "나중에" persists the new reminder through `TodoRepository.setReminder`,
///   which re-enters the pipeline via the `reminderChanged` hook.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    /// Frozen category identifiers — they live inside delivered notifications.
    enum CategoryID {
        static let task = "TASK_REMINDER"
        static let routine = "ROUTINE_REMINDER"
        static let review = "DAILY_REVIEW"
        static let focus = "FOCUS_SESSION"
    }

    /// Frozen action identifiers — same reason.
    enum ActionID {
        static let complete = "TASK_COMPLETE"
        static let later = "TASK_LATER"
        static let moveToToday = "TASK_MOVE_TODAY"
        static let startFocus = "TASK_START_FOCUS"
        static let open = "TASK_OPEN"
        static let routineComplete = "ROUTINE_COMPLETE"
        static let routineOpen = "ROUTINE_OPEN"
        static let reviewOpen = "REVIEW_OPEN"
        static let focusComplete = "FOCUS_COMPLETE"
        static let focusOpen = "FOCUS_OPEN"
    }

    private let center = UNUserNotificationCenter.current()
    private let log = Logger(subsystem: "com.hwangtodo.app", category: "NotificationManager")
    private let responder = NotificationResponder()
    private var repository: TodoRepository?
    private var router: AppRouter?
    /// Guards against double-wiring the repository hooks.
    private var bootstrappedRepositoryID: ObjectIdentifier?

    private static let taskIdentifierPrefix = "task-"
    private static let routineIdentifierPrefix = "routine-"
    private static let dailyReviewIdentifier = "daily-review"
    private static let focusSessionIdentifier = "focus-session"
    private static let testIdentifier = "test-notification"
    private static let dailyReviewMinutesKey = "dailyReviewMinutes"
    private static let defaultDailyReviewMinutes = 21 * 60

    private init() {}

    // MARK: - Bootstrap

    /// Installs the notification delegate (synchronously, before returning),
    /// registers Korean action categories, and wires repository hooks so every
    /// reminder mutation keeps pending notifications in sync.
    func bootstrap(repository: TodoRepository, router: AppRouter) {
        UNUserNotificationCenter.current().delegate = responder
        self.router = router
        guard bootstrappedRepositoryID != ObjectIdentifier(repository) else { return }
        bootstrappedRepositoryID = ObjectIdentifier(repository)
        self.repository = repository
        registerCategories()
        wireHooks(into: repository)
        resyncAll()
    }

    // MARK: - Authorization & test

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted { resyncAll() }
            return granted
        } catch {
            log.error("notification authorization failed: \(error, privacy: .public)")
            return false
        }
    }

    /// 5초 뒤 예시 알림 — 설정 체크리스트의 "테스트하기". Carries no task id,
    /// so task actions on it log and do nothing.
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "이렇게 알려 드려요"
        content.body = "할 일 알림이 오면 잠금화면에서 바로 완료하거나 미룰 수 있어요."
        content.sound = .default
        content.categoryIdentifier = CategoryID.task
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        add(UNNotificationRequest(identifier: Self.testIdentifier, content: content, trigger: trigger))
    }

    // MARK: - 하루 점검

    /// 하루 점검 알림 시각, 자정 기준 분 (기본 21:00). Persisted under the
    /// "dailyReviewMinutes" key so 설정 can bind the same value via
    /// `@AppStorage`; setting it reschedules immediately.
    var dailyReviewMinutes: Int {
        get {
            UserDefaults.standard.object(forKey: Self.dailyReviewMinutesKey) as? Int
                ?? Self.defaultDailyReviewMinutes
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.dailyReviewMinutesKey)
            scheduleDailyReview()
        }
    }

    // MARK: - Routine reminders

    /// Rebuilds every routine reminder from the store: cancels all pending
    /// "routine-…" requests, then schedules active routines with a reminder
    /// time — daily, or weekly per selected weekday. Call after any routine
    /// mutation.
    func syncRoutineReminders() {
        Task { [weak self] in
            await self?.performRoutineSync()
        }
    }

    private func performRoutineSync() async {
        guard let repository else { return }
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(Self.routineIdentifierPrefix) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }
        for routine in repository.routines {
            scheduleRoutineReminder(for: routine)
        }
    }

    private func scheduleRoutineReminder(for routine: Routine) {
        guard routine.isActive, let minutes = routine.reminderMinutes else { return }
        let hour = minutes / 60
        let minute = minutes % 60

        let content = UNMutableNotificationContent()
        content.title = routine.title
        content.body = "오늘의 루틴이에요. 완료하면 바로 체크할 수 있어요."
        content.sound = .default
        content.categoryIdentifier = CategoryID.routine
        content.userInfo = ["routineID": routine.id.uuidString]
        content.threadIdentifier = "routine-reminders"

        if routine.weekdays.isEmpty {
            // 매일 — one repeating daily trigger.
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: hour, minute: minute),
                repeats: true
            )
            add(UNNotificationRequest(
                identifier: "\(Self.routineIdentifierPrefix)\(routine.id.uuidString)",
                content: content,
                trigger: trigger
            ))
        } else {
            // One repeating weekly trigger per selected weekday.
            for weekday in routine.weekdays {
                var components = DateComponents(hour: hour, minute: minute)
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                add(UNNotificationRequest(
                    identifier: "\(Self.routineIdentifierPrefix)\(routine.id.uuidString)-w\(weekday)",
                    content: content,
                    trigger: trigger
                ))
            }
        }
    }

    // MARK: - Task reminders

    private func scheduleTaskReminder(for item: TodoItem) {
        cancelTaskNotifications(taskID: item.id)
        guard let date = item.reminderDate, item.isOpen else { return }
        guard date > .now else {
            log.info("skipping past reminder for task \(item.id.uuidString, privacy: .public)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = "예약해 둔 알림이에요. 지금 확인해 보세요."
        content.sound = .default
        content.categoryIdentifier = CategoryID.task
        content.userInfo = ["taskID": item.id.uuidString]
        content.threadIdentifier = "task-reminders"

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        add(UNNotificationRequest(
            identifier: Self.taskIdentifier(item.id),
            content: content,
            trigger: trigger
        ))
    }

    private func cancelTaskNotifications(taskID: UUID) {
        let identifier = Self.taskIdentifier(taskID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - Response handling (MainActor side of the delegate)

    func handleResponse(
        actionID: String,
        categoryID: String,
        requestID: String,
        taskIDString: String?,
        routineIDString: String?
    ) {
        guard actionID != UNNotificationDismissActionIdentifier else { return }
        switch categoryID {
        case CategoryID.task:
            handleTaskAction(actionID: actionID, requestID: requestID, taskIDString: taskIDString)
        case CategoryID.routine:
            handleRoutineAction(actionID: actionID, requestID: requestID, routineIDString: routineIDString)
        case CategoryID.review:
            if actionID == ActionID.reviewOpen || actionID == UNNotificationDefaultActionIdentifier {
                router?.navigate(to: .captureHome())
            }
        case CategoryID.focus:
            if actionID == ActionID.focusComplete {
                FocusSessionManager.shared.completeCurrent()
            } else if actionID == ActionID.focusOpen || actionID == UNNotificationDefaultActionIdentifier {
                router?.navigate(to: .focus)
            }
        default:
            log.notice("unknown notification category \(categoryID, privacy: .public)")
        }
    }

    private func handleTaskAction(actionID: String, requestID: String, taskIDString: String?) {
        guard let repository else { return }
        guard let id = Self.resolveTaskID(requestID: requestID, fallback: taskIDString) else {
            // The test notification (and nothing else) has no task id.
            log.info("task action \(actionID, privacy: .public) without a task id — nothing to do")
            return
        }
        guard let item = repository.task(withID: id) else {
            // The task is gone; never redirect the action to another task.
            log.notice("task action for missing task \(id.uuidString, privacy: .public) — ignored")
            return
        }
        switch actionID {
        case ActionID.complete where item.isOpen:
            repository.markDone(item)
        case ActionID.later where item.isOpen:
            repository.setReminder(item, at: Date.now.addingTimeInterval(3600))
        case ActionID.moveToToday where item.isOpen:
            repository.moveToToday(item)
        case ActionID.complete, ActionID.later, ActionID.moveToToday:
            // A stale banner for a task completed/archived elsewhere must not
            // mutate it back to life.
            log.notice("mutating action on closed task \(id.uuidString, privacy: .public) — ignored")
        case ActionID.startFocus:
            router?.navigate(to: .focus)
            FocusSessionManager.shared.start(queue: [item])
        case ActionID.open, UNNotificationDefaultActionIdentifier:
            router?.navigate(to: .task(id))
        default:
            log.notice("unknown task action \(actionID, privacy: .public)")
        }
    }

    private func handleRoutineAction(actionID: String, requestID: String, routineIDString: String?) {
        guard let repository else { return }
        guard let id = Self.resolveRoutineID(requestID: requestID, fallback: routineIDString),
              let routine = repository.routine(withID: id) else {
            log.notice("routine action for missing routine — ignored")
            return
        }
        switch actionID {
        case ActionID.routineComplete:
            // 완료 is idempotent — a second tap never un-completes.
            if !routine.isCompleted(on: .now) {
                repository.toggleRoutineCompletion(routine)
            }
        case ActionID.routineOpen, UNNotificationDefaultActionIdentifier:
            router?.navigate(to: .routines)
        default:
            log.notice("unknown routine action \(actionID, privacy: .public)")
        }
    }

    // MARK: - Wiring

    private func wireHooks(into repository: TodoRepository) {
        // Chain instead of overwrite — other subsystems (Live Activity) may
        // install hooks on the same repository.
        let completed = repository.hooks.taskCompleted
        repository.hooks.taskCompleted = { [weak self] item in
            completed(item)
            self?.cancelTaskNotifications(taskID: item.id)
        }
        let removed = repository.hooks.taskRemoved
        repository.hooks.taskRemoved = { [weak self] id in
            removed(id)
            self?.cancelTaskNotifications(taskID: id)
        }
        let reminderChanged = repository.hooks.reminderChanged
        repository.hooks.reminderChanged = { [weak self] item in
            reminderChanged(item)
            self?.scheduleTaskReminder(for: item)
        }
    }

    private func registerCategories() {
        let taskCategory = UNNotificationCategory(
            identifier: CategoryID.task,
            actions: [
                UNNotificationAction(identifier: ActionID.complete, title: "완료"),
                UNNotificationAction(identifier: ActionID.later, title: "나중에"),
                UNNotificationAction(identifier: ActionID.moveToToday, title: "오늘로 이동"),
                UNNotificationAction(identifier: ActionID.startFocus, title: Terminology.startFocus, options: [.foreground]),
                UNNotificationAction(identifier: ActionID.open, title: "열기", options: [.foreground]),
            ],
            intentIdentifiers: []
        )
        let routineCategory = UNNotificationCategory(
            identifier: CategoryID.routine,
            actions: [
                UNNotificationAction(identifier: ActionID.routineComplete, title: "완료"),
                UNNotificationAction(identifier: ActionID.routineOpen, title: "열기", options: [.foreground]),
            ],
            intentIdentifiers: []
        )
        let reviewCategory = UNNotificationCategory(
            identifier: CategoryID.review,
            actions: [
                UNNotificationAction(identifier: ActionID.reviewOpen, title: "열기", options: [.foreground]),
            ],
            intentIdentifiers: []
        )
        let focusCategory = UNNotificationCategory(
            identifier: CategoryID.focus,
            actions: [
                UNNotificationAction(identifier: ActionID.focusComplete, title: "완료"),
                UNNotificationAction(identifier: ActionID.focusOpen, title: "열기", options: [.foreground]),
            ],
            intentIdentifiers: []
        )
        center.setNotificationCategories([taskCategory, routineCategory, reviewCategory, focusCategory])
    }

    // MARK: - 집중 알림 (spec §6.7)

    /// The Live Matrix fallback: when Live Activities are unavailable, a
    /// notification is the only surface telling the user a focus session is
    /// running. Posted by FocusSessionManager on start; cleared on end.
    func notifyFocusSession(taskTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(Terminology.startFocus): \(taskTitle)"
        content.body = "실시간 현황을 켤 수 없어 알림으로 알려 드려요. 끝나면 완료를 눌러 주세요."
        content.sound = .default
        content.categoryIdentifier = CategoryID.focus
        content.threadIdentifier = Self.focusSessionIdentifier
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        add(UNNotificationRequest(identifier: Self.focusSessionIdentifier, content: content, trigger: trigger))
    }

    func clearFocusSessionNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.focusSessionIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.focusSessionIdentifier])
    }

    /// Re-schedules everything schedulable from the store. Idempotent —
    /// identifiers are stable, so re-adding replaces.
    private func resyncAll() {
        guard let repository else { return }
        for item in repository.items where item.isOpen && item.reminderDate != nil {
            scheduleTaskReminder(for: item)
        }
        pruneStaleTaskReminders()
        syncRoutineReminders()
        scheduleDailyReview()
    }

    /// Removes pending task reminders whose task is gone or no longer open.
    /// The repository hooks only see in-app mutations — completions made in
    /// the widget process (interactive widget button, Live Activity 완료)
    /// bypass them, so this sweep runs at launch and on every foreground.
    func pruneStaleTaskReminders() {
        guard let repository else { return }
        let liveIdentifiers = Set(
            repository.items
                .filter { $0.isOpen && $0.reminderDate != nil }
                .map { Self.taskIdentifier($0.id) }
        )
        let center = center
        let log = log
        Task {
            let pending = await center.pendingNotificationRequests().map(\.identifier)
            let stale = pending.filter { $0.hasPrefix(Self.taskIdentifierPrefix) && !liveIdentifiers.contains($0) }
            guard !stale.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            center.removeDeliveredNotifications(withIdentifiers: stale)
            log.info("pruned \(stale.count) stale task reminders")
        }
    }

    private func scheduleDailyReview() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReviewIdentifier])
        let minutes = dailyReviewMinutes
        let content = UNMutableNotificationContent()
        content.title = "하루 점검"
        content.body = "오늘 한 일을 돌아보고, 떠오른 일을 남겨 보세요."
        content.sound = .default
        content.categoryIdentifier = CategoryID.review
        content.threadIdentifier = Self.dailyReviewIdentifier
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60),
            repeats: true
        )
        add(UNNotificationRequest(identifier: Self.dailyReviewIdentifier, content: content, trigger: trigger))
    }

    // MARK: - Internals

    private func add(_ request: UNNotificationRequest) {
        let identifier = request.identifier
        let log = log
        center.add(request) { error in
            if let error {
                log.error("failed to schedule \(identifier, privacy: .public): \(error, privacy: .public)")
            }
        }
    }

    private static func taskIdentifier(_ id: UUID) -> String {
        "\(taskIdentifierPrefix)\(id.uuidString)"
    }

    /// "task-<uuid>" → UUID; userInfo string as fallback.
    private static func resolveTaskID(requestID: String, fallback: String?) -> UUID? {
        if requestID.hasPrefix(taskIdentifierPrefix),
           let id = UUID(uuidString: String(requestID.dropFirst(taskIdentifierPrefix.count))) {
            return id
        }
        return fallback.flatMap(UUID.init(uuidString:))
    }

    /// "routine-<uuid>" or "routine-<uuid>-w<weekday>" → UUID; userInfo fallback.
    private static func resolveRoutineID(requestID: String, fallback: String?) -> UUID? {
        if let id = fallback.flatMap(UUID.init(uuidString:)) { return id }
        guard requestID.hasPrefix(routineIdentifierPrefix) else { return nil }
        let suffix = requestID.dropFirst(routineIdentifierPrefix.count)
        return UUID(uuidString: String(suffix.prefix(36)))
    }
}

/// The one `UNUserNotificationCenterDelegate`. Deliberately `nonisolated`:
/// the system may call it off the main thread, so each callback extracts
/// Sendable values and hops to the MainActor manager.
private nonisolated final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate {
    /// Foreground delivery still shows banner + sound (spec §6.7 reliability).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionID = response.actionIdentifier
        let request = response.notification.request
        let categoryID = request.content.categoryIdentifier
        let requestID = request.identifier
        let taskIDString = request.content.userInfo["taskID"] as? String
        let routineIDString = request.content.userInfo["routineID"] as? String
        await NotificationManager.shared.handleResponse(
            actionID: actionID,
            categoryID: categoryID,
            requestID: requestID,
            taskIDString: taskIDString,
            routineIDString: routineIDString
        )
    }
}
