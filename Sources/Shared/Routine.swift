import Foundation

/// A repeating habit (todo mate–style). Routines are NOT one-off tasks: a routine
/// is "scheduled" on certain weekdays and tracks day-granular completion history.
/// Quadrant is optional — fast capture never forces matrix thinking.
struct Routine: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    /// Weekdays it runs on (1=Sun … 7=Sat). Empty means every day.
    var weekdays: [Int]
    var isActive: Bool
    var defaultQuadrantRaw: String?
    var createdAt: Date
    /// Days (start-of-day) on which the routine was completed.
    var completionDates: [Date]

    init(id: UUID = UUID(), title: String, weekdays: [Int] = [], isActive: Bool = true,
         defaultQuadrant: MatrixQuadrant? = nil, createdAt: Date = .now, completionDates: [Date] = []) {
        self.id = id
        self.title = title
        self.weekdays = weekdays
        self.isActive = isActive
        self.defaultQuadrantRaw = defaultQuadrant?.rawValue
        self.createdAt = createdAt
        self.completionDates = completionDates
    }

    var defaultQuadrant: MatrixQuadrant? {
        get { defaultQuadrantRaw.flatMap(MatrixQuadrant.init(rawValue:)) }
        set { defaultQuadrantRaw = newValue?.rawValue }
    }

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isActive else { return false }
        if weekdays.isEmpty { return true }
        return weekdays.contains(calendar.component(.weekday, from: date))
    }

    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return completionDates.contains { calendar.isDate($0, inSameDayAs: day) }
    }

    /// Korean summary of the repeat cycle.
    var cycleDescription: String {
        if weekdays.isEmpty { return "매일" }
        if Set(weekdays) == [2, 3, 4, 5, 6] { return "평일" }
        if Set(weekdays) == [1, 7] { return "주말" }
        let names = ["", "일", "월", "화", "수", "목", "금", "토"]
        return weekdays.sorted().map { names[$0] }.joined(separator: "·") + "요일"
    }
}
