import Foundation
import UserNotifications

/// Local notifications: per-task reminders, urgent "지금 하기" nudges, and a daily
/// review. Ordinary local notifications — iOS does not allow custom interactive
/// Notification Center input, so we don't claim it. Actions update shared state.
@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let reviewID = "hwangtodo.matrix.review"

    var router: AppRouter?
    var model: TaskModel?

    private override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    private func registerCategories() {
        let complete = UNNotificationAction(identifier: "COMPLETE", title: "완료", options: [])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "나중에", options: [])
        let moveToday = UNNotificationAction(identifier: "MOVE_TODAY", title: "오늘로 이동", options: [])
        let startFocus = UNNotificationAction(identifier: "START_FOCUS", title: "집중 시작", options: [.foreground])
        let open = UNNotificationAction(identifier: "OPEN", title: "열기", options: [.foreground])

        let task = UNNotificationCategory(identifier: "TASK_REMINDER",
                                          actions: [complete, snooze, moveToday, startFocus, open],
                                          intentIdentifiers: [], options: [])
        let review = UNNotificationCategory(identifier: "MATRIX_REVIEW",
                                            actions: [open, complete],
                                            intentIdentifiers: [], options: [])
        center.setNotificationCategories([task, review])
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        return granted
    }

    private func ensureAuthorized() async -> Bool {
        await refreshAuthorizationStatus()
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined: return await requestAuthorization()
        default: return false
        }
    }

    func scheduleReminder(id: UUID, title: String, date: Date) async {
        guard await ensureAuthorized(), date > .now else { return }
        cancelReminder(id: id)
        let content = UNMutableNotificationContent()
        content.title = "지금 할 일"
        content.body = title
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = ["url": DeepLink.matrix.absoluteString, "taskID": id.uuidString]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        try? await center.add(UNNotificationRequest(
            identifier: id.uuidString, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    func cancelReminder(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    func scheduleTestNotification() async {
        guard await ensureAuthorized() else { return }
        let content = UNMutableNotificationContent()
        content.title = "HWANGTODO"
        let inbox = TaskStore.shared.inboxCount
        content.body = inbox > 0 ? "정리하지 않은 할 일이 \(inbox)개 있어요. 매트릭스로 정리해 보세요." : "받은함이 깨끗해요. 좋아요."
        content.sound = .default
        content.categoryIdentifier = "MATRIX_REVIEW"
        content.userInfo = ["url": DeepLink.inbox.absoluteString]
        try? await center.add(UNNotificationRequest(
            identifier: "hwangtodo.test", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }

    func scheduleDailyReview(hour: Int, minute: Int) async {
        guard await ensureAuthorized() else { return }
        cancelDailyReview()
        let content = UNMutableNotificationContent()
        content.title = "오늘 정리"
        content.body = "받은함을 정리하고 지금 할 일을 정해 보세요."
        content.sound = .default
        content.categoryIdentifier = "MATRIX_REVIEW"
        content.userInfo = ["url": DeepLink.inbox.absoluteString]
        var comps = DateComponents(); comps.hour = hour; comps.minute = minute
        try? await center.add(UNNotificationRequest(
            identifier: reviewID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
    }

    func cancelDailyReview() {
        center.removePendingNotificationRequests(withIdentifiers: [reviewID])
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions { [.banner, .sound] }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let urlString = info["url"] as? String
        let taskID = (info["taskID"] as? String).flatMap(UUID.init(uuidString:))
        let actionID = response.actionIdentifier
        await MainActor.run {
            switch actionID {
            case "COMPLETE":
                if let model {
                    if let taskID, let t = model.task(with: taskID) { model.markDone(t) }
                    else if let latest = model.inbox.first { model.markDone(latest) }
                }
            case "MOVE_TODAY":
                if let taskID, let model, let t = model.task(with: taskID) { model.moveToToday(t) }
                router?.handle(url: DeepLink.calendar)
            case "SNOOZE":
                if let taskID, let model, let t = model.task(with: taskID) {
                    Task { await self.scheduleReminder(id: t.id, title: t.title, date: .now.addingTimeInterval(3600)) }
                }
            case "START_FOCUS":
                router?.handle(url: DeepLink.focus)
            default:
                if let urlString, let url = URL(string: urlString) { router?.handle(url: url) }
                else { router?.handle(url: DeepLink.inbox) }
            }
        }
    }
}
