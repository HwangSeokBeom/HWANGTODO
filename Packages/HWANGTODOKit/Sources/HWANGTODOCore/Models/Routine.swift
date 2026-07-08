import Foundation
import SwiftData

/// A lightweight repeating habit (spec §10). Deliberately simple: weekday
/// selection only — no every-N-days/monthly machinery.
@Model
public final class Routine {
    @Attribute(.unique) public var id: UUID
    public var title: String
    /// Weekdays this routine is scheduled on, using `Calendar` numbering
    /// (1 = Sunday … 7 = Saturday). Empty means **every day**.
    public var weekdays: [Int]
    public var isActive: Bool
    /// Optional matrix quadrant this routine belongs to (spec §10).
    public var defaultQuadrantRaw: String?
    /// Optional daily reminder, stored as minutes from midnight (DST-safe).
    public var reminderMinutes: Int?
    public var createdAt: Date
    /// Day-start dates on which the routine was completed (bounded; see `markCompleted`).
    public var completedDays: [Date]

    public init(
        id: UUID = UUID(),
        title: String,
        weekdays: [Int] = [],
        isActive: Bool = true,
        defaultQuadrant: Quadrant? = nil,
        reminderMinutes: Int? = nil,
        createdAt: Date = .now,
        completedDays: [Date] = []
    ) {
        self.id = id
        self.title = title
        self.weekdays = weekdays.sorted()
        self.isActive = isActive
        defaultQuadrantRaw = defaultQuadrant?.rawValue
        self.reminderMinutes = reminderMinutes
        self.createdAt = createdAt
        self.completedDays = completedDays
    }

    public var defaultQuadrant: Quadrant? {
        get { defaultQuadrantRaw.flatMap(Quadrant.init(rawValue:)) }
        set { defaultQuadrantRaw = newValue?.rawValue }
    }

    // MARK: - Scheduling

    /// Whether the routine is scheduled on `date` (active + weekday matches).
    public func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isActive else { return false }
        guard !weekdays.isEmpty else { return true }
        return weekdays.contains(calendar.component(.weekday, from: date))
    }

    public func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        completedDays.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    public func toggleCompletion(on date: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        if let index = completedDays.firstIndex(where: { calendar.isDate($0, inSameDayAs: day) }) {
            completedDays.remove(at: index)
        } else {
            completedDays.append(day)
            // Keep history bounded — a year of dailies is plenty for streaks/rates.
            if completedDays.count > 400 {
                completedDays.sort()
                completedDays.removeFirst(completedDays.count - 400)
            }
        }
    }

    // MARK: - Stats (todo mate-style 완료감)

    /// Completion rate over the trailing `days` window, counting only days the
    /// routine was actually scheduled. Returns nil when nothing was scheduled.
    public func completionRate(days: Int = 28, until reference: Date = .now, calendar: Calendar = .current) -> Double? {
        let end = calendar.startOfDay(for: reference)
        var scheduled = 0
        var completed = 0
        for offset in 0 ..< days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { continue }
            guard day >= calendar.startOfDay(for: createdAt) else { break }
            guard isScheduled(on: day, calendar: calendar) else { continue }
            scheduled += 1
            if isCompleted(on: day, calendar: calendar) { completed += 1 }
        }
        guard scheduled > 0 else { return nil }
        return Double(completed) / Double(scheduled)
    }

    /// Consecutive scheduled-day completions ending today (or yesterday if
    /// today is not yet complete).
    public func currentStreak(reference: Date = .now, calendar: Calendar = .current) -> Int {
        var streak = 0
        var day = calendar.startOfDay(for: reference)
        // Today may still be in progress; start counting from the most recent
        // scheduled day that is completed.
        if isScheduled(on: day, calendar: calendar), !isCompleted(on: day, calendar: calendar) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = previous
        }
        for _ in 0 ..< 400 {
            if isScheduled(on: day, calendar: calendar) {
                guard isCompleted(on: day, calendar: calendar) else { break }
                streak += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            guard previous >= calendar.startOfDay(for: createdAt) else { break }
            day = previous
        }
        return streak
    }

    /// Human description of the repeat cycle, e.g. "매일", "월·수·금".
    public var cycleDescription: String {
        guard !weekdays.isEmpty else { return "매일" }
        if weekdays.sorted() == [1, 7] { return "주말" }
        if weekdays.sorted() == [2, 3, 4, 5, 6] { return "평일" }
        let names = ["", "일", "월", "화", "수", "목", "금", "토"]
        return weekdays.sorted().map { names[$0] }.joined(separator: "·")
    }
}
