import HWANGTODOCore
import HWANGTODODesign
import SwiftData
import SwiftUI

/// 루틴 tab (spec §10): fast and simple — 오늘 완료율 header, 오늘의 루틴
/// one-tap check rows, and the full routine list with activate/edit/delete.
/// Deliberately not a repeat-scheduler app: weekday selection is the only
/// recurrence machinery.
///
/// Every routine mutation goes through `TodoRepository`, then re-syncs pending
/// routine reminders via `NotificationManager.syncRoutineReminders()` so the
/// notification pipeline never drifts from the store.
struct RoutineListView: View {
    @Environment(TodoRepository.self) private var repository

    /// Bumped once per newly-completed routine — drives the success haptic.
    @State private var completionPulse = 0
    @State private var isAddingRoutine = false
    @State private var editingRoutine: Routine?

    /// spec §10's 예시 루틴 — one tap creates a real routine.
    private static let exampleTitles = [
        "물 마시기", "운동하기", "출근 전 체크", "업무일지 작성",
        "퇴근 전 정리", "캘린더 확인", "책 읽기",
    ]

    var body: some View {
        NavigationStack {
            List {
                headerCard
                if repository.routines.isEmpty {
                    emptyContent
                } else {
                    todaySection
                    allSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.screenBackground)
            .contentMargins(.horizontal, Theme.Spacing.m, for: .scrollContent)
            .refreshable { repository.reload() }
            .navigationTitle(Terminology.tabRoutine)
            .navigationSubtitle("매일 반복하는 일을 가볍게")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingRoutine = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("루틴 추가")
                }
            }
            .sensoryFeedback(.success, trigger: completionPulse)
            .sheet(isPresented: $isAddingRoutine) {
                RoutineFormSheet(routine: nil)
            }
        }
        .sheet(item: $editingRoutine) { routine in
            RoutineFormSheet(routine: routine)
        }
    }

    // MARK: - 오늘 완료율 header (todo mate-style 완료감)

    private var headerCard: some View {
        let today = repository.todayRoutines
        let done = today.count { $0.isCompleted(on: .now) }
        let ratio = today.isEmpty ? 0 : Double(done) / Double(today.count)
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.l) {
                ZStack {
                    ProgressRing(progress: ratio, lineWidth: 6)
                    Text(today.isEmpty ? "—" : "\(Int(ratio * 100))%")
                        .font(Theme.Typography.meta)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 2) {
                    Text("오늘 완료율")
                        .font(Theme.Typography.sectionTitle)
                    Text(today.isEmpty ? "오늘 예정된 루틴이 없어요" : "\(today.count)개 중 \(done)개 완료")
                        .font(Theme.Typography.meta)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            weekBar
        }
        .cardSurface()
        .routineListRow()
    }

    /// Trailing 7-day completion strip: one bar per day, filled by that day's
    /// scheduled-routine completion rate. Empty track = nothing was scheduled.
    private var weekBar: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
            ForEach(trailingWeek, id: \.day) { entry in
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        Capsule()
                            .fill(Color.hwangAccent.opacity(0.12))
                        if let rate = entry.rate, rate > 0 {
                            Capsule()
                                .fill(Color.hwangAccent)
                                .frame(height: max(4, 36 * rate))
                        }
                    }
                    .frame(height: 36)
                    Text(entry.label)
                        .font(Theme.Typography.badge)
                        .foregroundStyle(entry.isToday ? Color.hwangAccent : Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement()
                .accessibilityLabel("\(entry.label)요일")
                .accessibilityValue(entry.rate.map { "\(Int($0 * 100))퍼센트 완료" } ?? "예정된 루틴 없음")
            }
        }
    }

    private struct WeekDayRate {
        let day: Date
        let label: String
        let rate: Double?
        let isToday: Bool
    }

    private var trailingWeek: [WeekDayRate] {
        let calendar = Calendar.current
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        let todayStart = calendar.startOfDay(for: .now)
        return (0 ..< 7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { return nil }
            // Mirror completionRate's createdAt boundary: a routine created
            // today must not rewrite past days as scheduled-and-missed.
            let scheduled = repository.routines.filter {
                day >= calendar.startOfDay(for: $0.createdAt) && $0.isScheduled(on: day, calendar: calendar)
            }
            let rate: Double? = scheduled.isEmpty
                ? nil
                : Double(scheduled.count { $0.isCompleted(on: day, calendar: calendar) }) / Double(scheduled.count)
            let weekdayIndex = calendar.component(.weekday, from: day) - 1
            return WeekDayRate(day: day, label: names[weekdayIndex], rate: rate, isToday: offset == 0)
        }
    }

    // MARK: - 오늘의 루틴

    @ViewBuilder private var todaySection: some View {
        let today = repository.todayRoutines
        SectionHeader("오늘의 루틴").routineListRow()
        if today.isEmpty {
            EmptyStateView(
                symbol: "moon.zzz",
                title: "오늘 예정된 루틴이 없어요",
                message: "쉬어 가는 날이에요. 필요하면 새 루틴을 추가해 보세요"
            )
            .routineListRow()
        } else {
            ForEach(today) { routine in
                todayRoutineRow(routine)
            }
        }
    }

    private func todayRoutineRow(_ routine: Routine) -> some View {
        let isCompleted = routine.isCompleted(on: .now)
        let streak = routine.currentStreak()
        return HStack(spacing: Theme.Spacing.m) {
            Button {
                withAnimation(.hwangSnappy) { repository.toggleRoutineCompletion(routine) }
                if !isCompleted { completionPulse += 1 }
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(isCompleted ? Color.hwangAccent : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCompleted ? "\(routine.title) 완료 취소" : "\(routine.title) 완료")

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(routine.title)
                    .font(Theme.Typography.cardTitle)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(2)
                if streak >= 3 || routine.defaultQuadrant != nil {
                    HStack(spacing: Theme.Spacing.xs) {
                        if streak >= 3 {
                            Label("\(streak)일 연속", systemImage: "flame.fill")
                                .font(Theme.Typography.badge)
                                .foregroundStyle(.orange)
                        }
                        if let quadrant = routine.defaultQuadrant {
                            QuadrantTag(quadrant, compact: true)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            if let rate = routine.completionRate(days: 28) {
                ProgressRing(progress: rate, lineWidth: 4)
                    .frame(width: 26, height: 26)
                    .accessibilityLabel("최근 4주 완료율")
            }
        }
        .cardSurface()
        .routineListRow()
    }

    // MARK: - 전체 루틴

    @ViewBuilder private var allSection: some View {
        SectionHeader("전체 루틴") {
            Text("\(repository.routines.count)")
                .font(Theme.Typography.meta)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .routineListRow()
        ForEach(repository.routines) { routine in
            allRoutineRow(routine)
        }
    }

    private func allRoutineRow(_ routine: Routine) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                editingRoutine = routine
            } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(routine.title)
                        .font(Theme.Typography.cardTitle)
                        .lineLimit(2)
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(routine.cycleDescription)
                            .font(Theme.Typography.meta)
                            .foregroundStyle(.secondary)
                        if let minutes = routine.reminderMinutes {
                            Label(Self.timeText(minutes: minutes), systemImage: "bell")
                                .font(Theme.Typography.badge)
                                .foregroundStyle(.secondary)
                        }
                        if let quadrant = routine.defaultQuadrant {
                            QuadrantTag(quadrant, compact: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("루틴 편집")

            Toggle("", isOn: activeBinding(for: routine))
                .labelsHidden()
                .tint(Color.hwangAccent)
                .accessibilityLabel("\(routine.title) 사용")
        }
        .cardSurface()
        .opacity(routine.isActive ? 1 : 0.45)
        .routineListRow()
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation(.hwangSnappy) {
                    repository.deleteRoutine(routine)
                    NotificationManager.shared.syncRoutineReminders()
                }
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    private func activeBinding(for routine: Routine) -> Binding<Bool> {
        Binding(
            get: { routine.isActive },
            set: { value in
                withAnimation(.hwangSnappy) { repository.setRoutineActive(routine, value) }
                NotificationManager.shared.syncRoutineReminders()
            }
        )
    }

    private static func timeText(minutes: Int) -> String {
        let calendar = Calendar.current
        guard let date = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) else {
            return String(format: "%d:%02d", minutes / 60, minutes % 60)
        }
        return date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - 빈 상태 + 예시 루틴 (spec §10)

    @ViewBuilder private var emptyContent: some View {
        EmptyStateView(
            symbol: "repeat",
            title: "아직 루틴이 없어요",
            message: "매일 반복하는 일을 루틴으로 만들면 완료율이 쌓여요"
        )
        .routineListRow()
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("이런 루틴은 어때요?")
                .font(Theme.Typography.meta)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: Theme.Spacing.xs)], spacing: Theme.Spacing.xs) {
                ForEach(Self.exampleTitles, id: \.self) { title in
                    Button {
                        withAnimation(.hwangSnappy) { _ = repository.addRoutine(title: title) }
                    } label: {
                        Label(title, systemImage: "plus")
                            .font(Theme.Typography.badge)
                            .lineLimit(1)
                            .padding(.horizontal, Theme.Spacing.s)
                            .padding(.vertical, Theme.Spacing.xs)
                            .frame(maxWidth: .infinity)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                            .foregroundStyle(Color.hwangAccent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) 루틴 만들기")
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .routineListRow()
    }
}

// MARK: - 추가/편집 공용 폼

/// Shared add/edit form (spec §10 — 복잡한 반복 설정 앱처럼 만들지 않는다):
/// 제목, 요일 캡슐 (없으면 매일), 선택적 분면, 선택적 알림 시간이 전부.
/// Saving re-syncs routine reminders so the pipeline matches the store.
private struct RoutineFormSheet: View {
    /// nil = 새 루틴 추가, non-nil = 기존 루틴 편집.
    let routine: Routine?

    @Environment(TodoRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var weekdays: Set<Int>
    @State private var quadrant: Quadrant?
    @State private var isReminderOn: Bool
    @State private var reminderTime: Date

    private static let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]
    /// Default reminder slot for new reminders: 09:00.
    private static let defaultReminderMinutes = 9 * 60

    init(routine: Routine?) {
        self.routine = routine
        _title = State(initialValue: routine?.title ?? "")
        _weekdays = State(initialValue: Set(routine?.weekdays ?? []))
        _quadrant = State(initialValue: routine?.defaultQuadrant)
        let minutes = routine?.reminderMinutes
        _isReminderOn = State(initialValue: minutes != nil)
        let seed = minutes ?? Self.defaultReminderMinutes
        let time = Calendar.current.date(bySettingHour: seed / 60, minute: seed % 60, second: 0, of: .now) ?? .now
        _reminderTime = State(initialValue: time)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("예: 물 마시기", text: $title)
                        .submitLabel(.done)
                }
                Section {
                    weekdayPicker
                } header: {
                    Text("반복 요일")
                } footer: {
                    Text(cycleFooter)
                }
                Section("분면") {
                    Picker("분면", selection: $quadrant) {
                        Text("없음").tag(Quadrant?.none)
                        ForEach(Quadrant.assignable) { choice in
                            Label(choice.title, systemImage: choice.symbol)
                                .tag(Quadrant?.some(choice))
                        }
                    }
                }
                Section {
                    Toggle("알림", isOn: $isReminderOn.animation(.hwangSnappy))
                    if isReminderOn {
                        DatePicker("알림 시간", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("알림 권한이 켜져 있어야 도착해요.")
                }
            }
            .navigationTitle(routine == nil ? "루틴 추가" : "루틴 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// 일–토 multi-select capsules; nothing selected = 매일.
    private var weekdayPicker: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(1 ... 7, id: \.self) { weekday in
                let isOn = weekdays.contains(weekday)
                Button {
                    withAnimation(.hwangSnappy) {
                        if isOn {
                            weekdays.remove(weekday)
                        } else {
                            weekdays.insert(weekday)
                        }
                    }
                } label: {
                    Text(Self.weekdayNames[weekday - 1])
                        .font(Theme.Typography.badge)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(isOn ? Color.hwangAccent : Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(Self.weekdayNames[weekday - 1])요일")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var cycleFooter: String {
        guard !weekdays.isEmpty else { return "요일을 선택하지 않으면 매일 반복돼요." }
        let names = weekdays.sorted().map { Self.weekdayNames[$0 - 1] }.joined(separator: "·")
        return "\(names)요일마다 반복돼요."
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let sortedWeekdays = weekdays.sorted()
        let minutes: Int? = isReminderOn ? minutesSinceMidnight(of: reminderTime) : nil
        if let routine {
            repository.updateRoutine(
                routine,
                title: trimmedTitle,
                weekdays: sortedWeekdays,
                defaultQuadrant: quadrant,
                reminderMinutes: minutes
            )
        } else {
            repository.addRoutine(
                title: trimmedTitle,
                weekdays: sortedWeekdays,
                defaultQuadrant: quadrant,
                reminderMinutes: minutes
            )
        }
        NotificationManager.shared.syncRoutineReminders()
        dismiss()
    }

    private func minutesSinceMidnight(of date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 9) * 60 + (components.minute ?? 0)
    }
}

/// Clears List chrome so card rows sit directly on the screen background.
private extension View {
    func routineListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: 0, bottom: Theme.Spacing.xs, trailing: 0))
    }
}

#if DEBUG
#Preview("루틴") {
    let container = RoutinePreviewData.container(seeded: true)
    RoutineListView()
        .environment(TodoRepository(context: container.mainContext))
        .environment(AppRouter())
        .modelContainer(container)
}

#Preview("빈 상태") {
    let container = RoutinePreviewData.container(seeded: false)
    RoutineListView()
        .environment(TodoRepository(context: container.mainContext))
        .environment(AppRouter())
        .modelContainer(container)
}

/// In-memory store exercising every 루틴 section: a streak, a weekday-limited
/// routine, a reminder time, and an inactive (dimmed) routine.
private enum RoutinePreviewData {
    static func container(seeded: Bool) -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: SharedStore.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        guard seeded else { return container }
        let context = container.mainContext
        let calendar = Calendar.current

        let water = Routine(title: "물 마시기", reminderMinutes: 9 * 60)
        for offset in 1 ... 5 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: .now) {
                water.toggleCompletion(on: day)
            }
        }
        let workout = Routine(title: "운동하기", weekdays: [2, 4, 6], defaultQuadrant: .importantNotUrgent)
        let journal = Routine(title: "업무일지 작성", weekdays: [2, 3, 4, 5, 6], reminderMinutes: 18 * 60)
        journal.toggleCompletion(on: .now)
        let reading = Routine(title: "책 읽기", isActive: false)
        [water, workout, journal, reading].forEach(context.insert)
        try? context.save()
        return container
    }
}
#endif
