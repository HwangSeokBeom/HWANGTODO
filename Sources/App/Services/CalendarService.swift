import Foundation
import EventKit
import Observation

/// EventKit integration. Permission is always explicit; we never write events
/// silently. Denied access is handled gracefully by the Calendar screen.
@MainActor
@Observable
final class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()
    var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private init() {}

    func refreshStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }

    @discardableResult
    func requestAccess() async -> Bool {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            granted = (try? await store.requestAccess(to: .event)) ?? false
        }
        refreshStatus()
        return granted
    }

    /// Today's events as a minimal, glanceable list.
    func todaysEvents() -> [EKEvent] {
        guard isAuthorized else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    func upcomingEvents(days: Int = 7) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let start = Date.now
        guard let end = Calendar.current.date(byAdding: .day, value: days, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    /// Creates a 1-hour event from a task. Returns the event identifier.
    func createEvent(title: String, start: Date, durationMinutes: Int = 60, notes: String? = nil) -> String? {
        guard isAuthorized else { return nil }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    func event(with identifier: String) -> EKEvent? {
        guard isAuthorized else { return nil }
        return store.event(withIdentifier: identifier)
    }
}
