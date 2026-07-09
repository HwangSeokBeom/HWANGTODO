import EventKit
import Foundation
import HWANGTODOCore
import Observation
import OSLog

/// Apple Calendar 연동이 실패한 이유 — 사용자에게 그대로 보여줄 수 있는 한국어 메시지.
enum CalendarServiceError: LocalizedError {
    /// Access denied/restricted; only Settings.app can fix it.
    case accessDenied
    /// No writable default calendar (e.g. all accounts read-only).
    case noWritableCalendar
    /// "추가만 허용" (write-only) access cannot read the already-linked event
    /// back, so updating would silently create a duplicate.
    case fullAccessRequiredToUpdate

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "캘린더 접근 권한이 없어요. 설정에서 캘린더 접근을 허용해 주세요."
        case .noWritableCalendar:
            "일정을 저장할 캘린더를 찾지 못했어요. 캘린더 앱에서 기본 캘린더를 확인해 주세요."
        case .fullAccessRequiredToUpdate:
            "이 할 일에는 이미 연결된 일정이 있어요. 중복 생성 없이 갱신하려면 설정에서 캘린더 전체 접근을 허용해 주세요."
        }
    }
}

/// Apple Calendar 연동 (spec §9): 할 일 → 캘린더 이벤트 생성/갱신, 오늘·예정
/// 일정 조회, 외부 삭제 감지.
///
/// Invariants:
/// - One `EKEventStore` per process; only single staged changes are ever
///   committed, and a failed save is `reset()` so nothing unrelated leaks
///   into a later commit.
/// - Unlinking never deletes the event — deleting is the calendar app's job.
/// - The task↔event link lives on `TodoItem.calendarEventID` and is written
///   only through `TodoRepository`.
@MainActor
@Observable
final class CalendarService {
    static let shared = CalendarService()

    /// Mirror of `EKEventStore.authorizationStatus(for: .event)` in 설정
    /// checklist vocabulary. Refresh via `refreshStatus()`.
    private(set) var accessState: SurfaceState

    /// Bumped whenever the calendar database changes (our save or an external
    /// edit). `.EKEventStoreChanged` carries no diff, so observers re-query.
    private(set) var storeVersion = 0

    /// "추가만 허용" — events can be created but the agenda cannot be read.
    /// ScheduleView shows an honest notice instead of a silently empty list.
    var isWriteOnly: Bool {
        EKEventStore.authorizationStatus(for: .event) == .writeOnly
    }

    private let store = EKEventStore()
    private let log = Logger(subsystem: "com.hwangtodo.app", category: "CalendarService")
    @ObservationIgnored private var changeObserver: (any NSObjectProtocol)?
    /// Debounces `.EKEventStoreChanged` bursts (iCloud/Exchange syncs post
    /// dozens in a row) so the UI re-queries once, not per notification.
    @ObservationIgnored private var pendingChange: Task<Void, Never>?

    private init() {
        accessState = Self.surfaceState(for: EKEventStore.authorizationStatus(for: .event))
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            // Delivered on the main queue; hop formally onto the actor.
            MainActor.assumeIsolated { self?.storeDidChange() }
        }
    }

    // MARK: - Access

    func refreshStatus() {
        accessState = Self.surfaceState(for: EKEventStore.authorizationStatus(for: .event))
        reloadEventCaches()
    }

    /// Requests full read/write access (needed for the 일정 agenda).
    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            refreshStatus()
            if granted { storeVersion += 1 }
            return granted
        } catch {
            log.error("calendar access request failed: \(error, privacy: .public)")
            refreshStatus()
            return false
        }
    }

    // MARK: - Scheduling (할 일 → 캘린더 이벤트)

    /// Creates — or, when the item already has a linked event that still
    /// exists, updates — the calendar event for `item`, then records the link
    /// and due date through the repository.
    ///
    /// Date resolution: `date` ?? `item.dueDate` ?? (existing event start when
    /// updating) ?? the next full hour. Duration is fixed at 1 hour.
    func scheduleEvent(for item: TodoItem, at date: Date?, repository: TodoRepository) async throws {
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            _ = await requestAccess()
        }
        refreshStatus()
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess || status == .writeOnly else { throw CalendarServiceError.accessDenied }
        if status == .writeOnly, item.hasCalendarEvent {
            // Write-only access cannot see the linked event, so "update"
            // would really be "create a duplicate" — refuse honestly.
            throw CalendarServiceError.fullAccessRequiredToUpdate
        }

        let existing = item.calendarEventID.flatMap { store.event(withIdentifier: $0) }
        let existingStart: Date? = existing?.startDate
        let startDate = date ?? item.dueDate ?? existingStart ?? Self.nextFullHour()

        let event: EKEvent
        if let existing {
            event = existing
        } else {
            guard let calendar = store.defaultCalendarForNewEvents else {
                throw CalendarServiceError.noWritableCalendar
            }
            let created = EKEvent(eventStore: store)
            created.calendar = calendar
            event = created
        }
        event.title = item.title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(3600)
        event.notes = DeepLink.task(item.id).url.absoluteString

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            // Discard the staged change so it can never ride along with a
            // later, unrelated commit.
            store.reset()
            log.error("calendar save failed for task \(item.id.uuidString, privacy: .public): \(error, privacy: .public)")
            throw error
        }

        repository.linkCalendarEvent(item, eventID: event.eventIdentifier)
        repository.schedule(item, at: startDate)
        reloadEventCaches()
        storeVersion += 1
        let action = existing == nil ? "created" : "updated"
        log.info("calendar event \(action, privacy: .public) for task \(item.id.uuidString, privacy: .public)")
    }

    /// Forgets the task↔event link. The event itself is left untouched —
    /// deleting it is the calendar app's job (spec §9).
    func unlinkEvent(for item: TodoItem, repository: TodoRepository) {
        guard item.hasCalendarEvent else { return }
        repository.linkCalendarEvent(item, eventID: nil)
    }

    /// Whether the linked event still exists in the calendar database.
    /// Without full read access we cannot verify, so we assume it exists —
    /// never fabricate a "캘린더에서 삭제됨" claim.
    func linkedEventExists(_ item: TodoItem) -> Bool {
        guard let eventID = item.calendarEventID, !eventID.isEmpty else { return false }
        guard hasFullReadAccess else { return true }
        return store.event(withIdentifier: eventID) != nil
    }

    // MARK: - Agenda queries (일정 화면)

    /// Cached — recomputed on `refreshStatus()`, after saves, and once per
    /// (debounced) external change, never inside a SwiftUI body evaluation.
    @ObservationIgnored private var todayEventsCache: [EKEvent] = []
    @ObservationIgnored private var upcomingEventsCache: [EKEvent] = []

    /// All of today's events across calendars, sorted by start time.
    /// Empty without full read access.
    func todayEvents() -> [EKEvent] { todayEventsCache }

    /// Events from tomorrow through the next 7 days, sorted by start time.
    /// Empty without full read access.
    func upcomingEvents() -> [EKEvent] { upcomingEventsCache }

    private func reloadEventCaches(calendar: Calendar = .current) {
        guard hasFullReadAccess else {
            todayEventsCache = []
            upcomingEventsCache = []
            return
        }
        let todayStart = calendar.startOfDay(for: .now)
        if let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) {
            todayEventsCache = events(from: todayStart, to: todayEnd)
            if let upcomingEnd = calendar.date(byAdding: .day, value: 7, to: todayEnd) {
                upcomingEventsCache = events(from: todayEnd, to: upcomingEnd)
            }
        }
    }

    // MARK: - Internals

    private var hasFullReadAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    private func events(from start: Date, to end: Date) -> [EKEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
    }

    private func storeDidChange() {
        pendingChange?.cancel()
        pendingChange = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            refreshStatus()
            storeVersion += 1
        }
    }

    private static func surfaceState(for status: EKAuthorizationStatus) -> SurfaceState {
        switch status {
        case .fullAccess: .available
        // "추가만 허용": events can be created but never read back — the 일정
        // agenda stays empty. 확인 필요, not a dishonest "사용 가능".
        case .writeOnly: .checkManually
        case .denied, .restricted: .denied
        case .notDetermined: .needsSetup
        @unknown default: .checkManually
        }
    }

    /// The next :00 o'clock after `date` — the default slot for "일정 잡기"
    /// with no explicit time.
    private static func nextFullHour(after date: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.nextDate(
            after: date,
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? date.addingTimeInterval(3600)
    }
}
