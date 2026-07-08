import Foundation
import HWANGTODOCore
import Testing

/// Routine scheduling/completion rules (spec §10). Every test uses a FIXED
/// gregorian calendar and constructed reference dates — the wall clock and the
/// device time zone never influence the outcome.
///
/// Fixed anchor week: 2026-06-01 and 2026-06-08 are Mondays; 2026-06-14 is a
/// Sunday (verified against the proleptic gregorian calendar).
@Suite("Routine — 스케줄과 완료")
@MainActor
struct RoutineTests {
    /// Deterministic calendar: gregorian, pinned to Asia/Seoul.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // Fixed components below always resolve in this time zone.
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    /// Noon on the given day — mid-day avoids any DST/day-boundary ambiguity.
    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: 12))!
    }

    // MARK: - isScheduled

    /// Empty `weekdays` means the routine runs every day (spec §10 단순함 우선).
    @Test("요일 미지정 = 매일")
    func emptyWeekdaysMeansEveryDay() {
        let routine = Routine(title: "물 마시기")
        #expect(routine.isScheduled(on: day(2026, 6, 8), calendar: calendar))  // Monday
        #expect(routine.isScheduled(on: day(2026, 6, 13), calendar: calendar)) // Saturday
        #expect(routine.isScheduled(on: day(2026, 6, 14), calendar: calendar)) // Sunday
    }

    @Test("비활성 루틴은 어떤 날에도 예정되지 않음")
    func inactiveRoutineIsNeverScheduled() {
        let routine = Routine(title: "운동하기", isActive: false)
        #expect(!routine.isScheduled(on: day(2026, 6, 8), calendar: calendar))
        #expect(!routine.isScheduled(on: day(2026, 6, 14), calendar: calendar))
    }

    @Test("선택한 요일에만 예정")
    func scheduledOnlyOnSelectedWeekdays() {
        let routine = Routine(title: "운동하기", weekdays: [2]) // Calendar weekday 2 = Monday
        #expect(routine.isScheduled(on: day(2026, 6, 8), calendar: calendar))  // Monday
        #expect(!routine.isScheduled(on: day(2026, 6, 9), calendar: calendar)) // Tuesday
    }

    // MARK: - toggleCompletion

    /// Toggling twice on the same day must return to "not completed" —
    /// no duplicate entries, no leftovers.
    @Test("완료 토글 두 번 = 원상복구")
    func toggleCompletionIsIdempotentPair() {
        let routine = Routine(title: "책 읽기")
        let monday = day(2026, 6, 8)

        routine.toggleCompletion(on: monday, calendar: calendar)
        #expect(routine.isCompleted(on: monday, calendar: calendar))

        routine.toggleCompletion(on: monday, calendar: calendar)
        #expect(!routine.isCompleted(on: monday, calendar: calendar))
        #expect(routine.completedDays.isEmpty)
    }

    // MARK: - completionRate

    /// Only days the routine was actually scheduled count toward the rate.
    @Test("완료율은 예정된 요일만 계산")
    func completionRateCountsOnlyScheduledDays() {
        let routine = Routine(title: "운동하기", weekdays: [2], createdAt: day(2026, 6, 1))
        routine.toggleCompletion(on: day(2026, 6, 8), calendar: calendar)

        // Window 2026-06-01…06-14 contains exactly two Mondays; one completed.
        let rate = routine.completionRate(days: 14, until: day(2026, 6, 14), calendar: calendar)
        #expect(rate == 0.5)
    }

    /// A window containing no scheduled day yields nil, not 0.
    @Test("예정된 날이 없으면 nil")
    func completionRateIsNilWhenNothingScheduled() {
        let mondayOnly = Routine(title: "운동하기", weekdays: [2], createdAt: day(2026, 6, 1))
        // 2026-06-09…06-14 (Tue–Sun) contains no Monday.
        #expect(mondayOnly.completionRate(days: 6, until: day(2026, 6, 14), calendar: calendar) == nil)

        let inactive = Routine(title: "쉬는 루틴", isActive: false, createdAt: day(2026, 6, 1))
        #expect(inactive.completionRate(days: 28, until: day(2026, 6, 14), calendar: calendar) == nil)
    }

    /// Days before the routine existed never enter the denominator.
    @Test("완료율은 생성일 이전을 세지 않음")
    func completionRateRespectsCreatedAtBoundary() {
        let routine = Routine(title: "업무일지 작성", createdAt: day(2026, 6, 12))
        routine.toggleCompletion(on: day(2026, 6, 13), calendar: calendar)
        routine.toggleCompletion(on: day(2026, 6, 14), calendar: calendar)

        // 28-day window, but only 06-12…06-14 are on/after createdAt → 2 of 3.
        let rate = routine.completionRate(days: 28, until: day(2026, 6, 14), calendar: calendar)
        #expect(rate == 2.0 / 3.0)
    }

    // MARK: - currentStreak

    /// An in-progress today must not break the streak — counting starts from
    /// yesterday when today is scheduled but not yet completed.
    @Test("오늘 미완료면 어제부터 연속 계산")
    func streakStartsYesterdayWhenTodayIncomplete() {
        let routine = Routine(title: "물 마시기", createdAt: day(2026, 6, 1))
        routine.toggleCompletion(on: day(2026, 6, 11), calendar: calendar)
        routine.toggleCompletion(on: day(2026, 6, 12), calendar: calendar)
        routine.toggleCompletion(on: day(2026, 6, 13), calendar: calendar)

        #expect(routine.currentStreak(reference: day(2026, 6, 14), calendar: calendar) == 3)
    }

    @Test("오늘 완료면 오늘 포함")
    func streakIncludesTodayWhenCompleted() {
        let routine = Routine(title: "물 마시기", createdAt: day(2026, 6, 1))
        routine.toggleCompletion(on: day(2026, 6, 13), calendar: calendar)
        routine.toggleCompletion(on: day(2026, 6, 14), calendar: calendar)

        #expect(routine.currentStreak(reference: day(2026, 6, 14), calendar: calendar) == 2)
    }

    /// A gap before yesterday means there is no current streak at all.
    @Test("끊긴 연속은 0")
    func brokenStreakIsZero() {
        let routine = Routine(title: "물 마시기", createdAt: day(2026, 6, 1))
        routine.toggleCompletion(on: day(2026, 6, 12), calendar: calendar) // two days ago only

        #expect(routine.currentStreak(reference: day(2026, 6, 14), calendar: calendar) == 0)
    }

    // MARK: - cycleDescription

    @Test("반복 주기 설명", arguments: [
        ([Int](), "매일"),
        ([2, 3, 4, 5, 6], "평일"),
        ([1, 7], "주말"),
        ([2, 4, 6], "월·수·금"),
    ])
    func cycleDescription(weekdays: [Int], expected: String) {
        #expect(Routine(title: "루틴", weekdays: weekdays).cycleDescription == expected)
    }
}
