import EventKit
import HWANGTODOCore
import HWANGTODODesign
import SwiftData
import SwiftUI
import UIKit

/// 일정 tab (spec §9): todo mate-style "오늘 계획 한눈에" — 지난 할 일,
/// 오늘의 통합 아젠다 (캘린더 이벤트 + 오늘 할 일), 다가오는 7일.
///
/// Calendar honesty rules:
/// - Access cards map 1:1 to `CalendarService.accessState` — a denied state is
///   shown as-is with a Settings jump, never silently hidden. Task lists keep
///   working without any calendar access.
/// - Calendar events render read-only; editing/deleting them is the calendar
///   app's job.
/// - A task whose linked event was deleted externally gets a
///   "캘린더에서 삭제됨" tag plus 연결 해제 — the link is only ever forgotten,
///   never re-fabricated (spec §9).
struct ScheduleView: View {
    @Environment(TodoRepository.self) private var repository
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    /// Bumped once per completion — drives the success haptic.
    @State private var completionPulse = 0
    @State private var isRequestingAccess = false

    private var calendarService: CalendarService { CalendarService.shared }

    var body: some View {
        // Reading both observable properties during body evaluation subscribes
        // the view to permission changes and to `.EKEventStoreChanged` bumps
        // (the service re-queries; we just re-render).
        let accessState = calendarService.accessState
        let _ = calendarService.storeVersion

        NavigationStack {
            List {
                headerCard
                accessCard(for: accessState)
                overdueSection
                todaySection
                upcomingSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.screenBackground)
            .contentMargins(.horizontal, Theme.Spacing.m, for: .scrollContent)
            .refreshable {
                repository.reload()
                calendarService.refreshStatus()
            }
            .navigationTitle(Terminology.tabSchedule)
            .navigationSubtitle("오늘 계획을 한눈에")
            .sensoryFeedback(.success, trigger: completionPulse)
        }
        .task { calendarService.refreshStatus() }
        .onChange(of: scenePhase) { _, phase in
            // The user may have just granted access in Settings.app.
            guard phase == .active else { return }
            calendarService.refreshStatus()
        }
    }

    // MARK: - 오늘 진행률 header (shared `dailyProgress` definition)

    private var headerCard: some View {
        let progress = repository.dailyProgress()
        let ratio = progress.total > 0 ? Double(progress.done) / Double(progress.total) : 0
        let remaining = max(progress.total - progress.done, 0)
        return HStack(spacing: Theme.Spacing.l) {
            ZStack {
                ProgressRing(progress: ratio, lineWidth: 6)
                Text(progress.total > 0 ? "\(Int(ratio * 100))%" : "—")
                    .font(Theme.Typography.meta)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline(remaining: remaining, total: progress.total))
                    .font(Theme.Typography.sectionTitle)
                if progress.total > 0 {
                    Text("완료 \(progress.done) · 전체 \(progress.total)")
                        .font(Theme.Typography.meta)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .cardSurface()
        .scheduleRow()
        .accessibilityElement(children: .combine)
    }

    private func headline(remaining: Int, total: Int) -> String {
        if total == 0 { return "오늘 예정된 일이 없어요" }
        return remaining > 0 ? "오늘 \(remaining)개 남음" : "오늘 할 일을 모두 마쳤어요"
    }

    // MARK: - 캘린더 권한 cards (spec §9)

    @ViewBuilder private func accessCard(for state: SurfaceState) -> some View {
        switch state {
        case .needsSetup:
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Label("캘린더와 연결하기", systemImage: "calendar.badge.plus")
                    .font(Theme.Typography.cardTitle)
                Text("Apple 캘린더를 연결하면 오늘 일정과 할 일을 한 화면에서 볼 수 있어요.")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
                Button {
                    requestAccess()
                } label: {
                    if isRequestingAccess {
                        ProgressView()
                    } else {
                        Text("캘린더 연결하기")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.hwangAccent)
                .disabled(isRequestingAccess)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
            .scheduleRow()
        case .denied:
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Label("캘린더 권한이 꺼져 있어요", systemImage: "calendar.badge.exclamationmark")
                    .font(Theme.Typography.cardTitle)
                Text("설정 앱에서 캘린더 접근을 허용하면 일정이 다시 보여요. 할 일 목록은 지금처럼 그대로 쓸 수 있어요.")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
                Button("설정 열기") { openSettingsApp() }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
            .scheduleRow()
        case .checkManually where calendarService.isWriteOnly:
            // "추가만 허용": we can create events but never read the agenda
            // back — say so instead of showing a silently empty list.
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Label("캘린더 추가만 허용돼 있어요", systemImage: "calendar.badge.checkmark")
                    .font(Theme.Typography.cardTitle)
                Text("일정 만들기는 되지만, 캘린더의 일정을 여기에 보여 주려면 설정에서 전체 접근을 허용해야 해요.")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
                Button("설정 열기") { openSettingsApp() }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
            .scheduleRow()
        case .available, .checkManually, .iosLimited:
            EmptyView()
        }
    }

    private func requestAccess() {
        guard !isRequestingAccess else { return }
        isRequestingAccess = true
        Task {
            _ = await CalendarService.shared.requestAccess()
            isRequestingAccess = false
        }
    }

    private func openSettingsApp() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    // MARK: - 지난 할 일

    @ViewBuilder private var overdueSection: some View {
        let overdue = repository.overdueTasks()
        if !overdue.isEmpty {
            SectionHeader("지난 할 일") {
                Text("\(overdue.count)")
                    .font(Theme.Typography.badge)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.red, in: Capsule())
                    .accessibilityLabel("지난 할 일 \(overdue.count)개")
            }
            .scheduleRow()
            ForEach(overdue) { item in
                taskRow(item, showsMoveToToday: true)
            }
        }
    }

    // MARK: - 오늘 (통합 아젠다)

    @ViewBuilder private var todaySection: some View {
        let entries = todayEntries
        SectionHeader("오늘") {
            if !entries.isEmpty {
                Text("\(entries.count)")
                    .font(Theme.Typography.meta)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .scheduleRow()
        if entries.isEmpty {
            EmptyStateView(
                symbol: "sun.max",
                title: "오늘은 비어 있어요",
                message: "정리 탭에서 일정 잡기로 하루 계획을 세워 보세요"
            )
            .scheduleRow()
        } else {
            ForEach(entries) { entry in
                agendaRow(entry)
            }
        }
    }

    /// Event identifiers already represented by a task card (일정 잡기 links
    /// them) — the task row is the actionable one, so its event must not
    /// render a second time (spec §9).
    private var linkedEventIDs: Set<String> {
        Set(repository.items.compactMap(\.calendarEventID))
    }

    /// Today's calendar events and today's tasks, merged and time-sorted —
    /// one agenda, not two lists (spec §9 "오늘 계획을 한눈에").
    private var todayEntries: [AgendaEntry] {
        let linked = linkedEventIDs
        let events = calendarService.todayEvents()
            .filter { !linked.contains($0.eventIdentifier ?? "") }
            .map { AgendaEntry.event(ScheduleEvent($0)) }
        let tasks = repository.todayTasks().map(AgendaEntry.task)
        return (events + tasks).sorted { $0.sortDate < $1.sortDate }
    }

    // MARK: - 다가오는 (7일 + 이후)

    @ViewBuilder private var upcomingSection: some View {
        let sections = upcomingDaySections
        let later = laterTasks
        if !sections.isEmpty || !later.isEmpty {
            SectionHeader("다가오는").scheduleRow()
            ForEach(sections) { section in
                dayHeader(label(for: section.day))
                ForEach(section.entries) { entry in
                    agendaRow(entry)
                }
            }
            if !later.isEmpty {
                dayHeader("이후")
                ForEach(later) { item in
                    taskRow(item)
                }
            }
        }
    }

    /// Tomorrow through +7 days: linked calendar events and due tasks grouped
    /// by day, each day time-sorted.
    private var upcomingDaySections: [DaySection] {
        let calendar = Calendar.current
        let linked = linkedEventIDs
        var buckets: [Date: [AgendaEntry]] = [:]
        for event in calendarService.upcomingEvents() {
            guard let start = event.startDate else { continue }
            guard !linked.contains(event.eventIdentifier ?? "") else { continue }
            buckets[calendar.startOfDay(for: start), default: []].append(.event(ScheduleEvent(event)))
        }
        for task in repository.upcomingTasks() {
            guard let due = task.dueDate, let horizon = upcomingHorizon, due < horizon else { continue }
            buckets[calendar.startOfDay(for: due), default: []].append(.task(task))
        }
        return buckets.keys.sorted().map { day in
            DaySection(day: day, entries: (buckets[day] ?? []).sorted { $0.sortDate < $1.sortDate })
        }
    }

    /// Open tasks due beyond the 7-day window — shown flat under "이후" so
    /// nothing scheduled ever disappears from the screen.
    private var laterTasks: [TodoItem] {
        guard let horizon = upcomingHorizon else { return [] }
        return repository.upcomingTasks().filter { ($0.dueDate ?? .distantPast) >= horizon }
    }

    /// End of the "next 7 days" window: start of today + 8 days.
    private var upcomingHorizon: Date? {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 8, to: calendar.startOfDay(for: .now))
    }

    private func label(for day: Date) -> String {
        let formatted = day.formatted(.dateTime.month().day().weekday(.short))
        return Calendar.current.isDateInTomorrow(day) ? "내일 · \(formatted)" : formatted
    }

    private func dayHeader(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.meta)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.top, Theme.Spacing.xs)
            .scheduleRow()
    }

    // MARK: - Rows

    @ViewBuilder private func agendaRow(_ entry: AgendaEntry) -> some View {
        switch entry {
        case .event(let event): eventRow(event)
        case .task(let item): taskRow(item)
        }
    }

    /// Read-only calendar event row — the calendar's color bar keeps it
    /// visually distinct from task cards.
    private func eventRow(_ event: ScheduleEvent) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.color)
                .frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(Theme.Typography.cardTitle)
                    .lineLimit(1)
                Text(event.timeText)
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "calendar")
                .font(Theme.Typography.badge)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .cardSurface()
        .scheduleRow()
        .accessibilityElement(children: .combine)
    }

    private func taskRow(_ item: TodoItem, showsMoveToToday: Bool = false) -> some View {
        Button {
            router.navigate(to: .task(item.id))
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TaskCardView(item: item)
                if isLinkedEventDeleted(item) {
                    Label("캘린더에서 삭제됨", systemImage: "calendar.badge.exclamationmark")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(.orange)
                        .padding(.leading, Theme.Spacing.m)
                }
            }
        }
        .buttonStyle(.plain)
        .scheduleRow()
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation(.hwangSnappy) { repository.markDone(item) }
                completionPulse += 1
            } label: {
                Label("완료", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            if showsMoveToToday {
                Button {
                    withAnimation(.hwangSnappy) { repository.moveToToday(item) }
                } label: {
                    Label("오늘 하기", systemImage: "sun.max")
                }
                .tint(Color.hwangAccent)
            }
            if isLinkedEventDeleted(item) {
                Button {
                    withAnimation(.hwangSnappy) {
                        CalendarService.shared.unlinkEvent(for: item, repository: repository)
                    }
                } label: {
                    Label("연결 해제", systemImage: "calendar.badge.minus")
                }
                .tint(.orange)
            }
        }
    }

    /// External-deletion safety (spec §9): true only when the item claims a
    /// link and the service could positively verify the event is gone.
    private func isLinkedEventDeleted(_ item: TodoItem) -> Bool {
        item.hasCalendarEvent && !CalendarService.shared.linkedEventExists(item)
    }
}

// MARK: - Agenda model

/// One merged agenda row: a read-only calendar event or a tappable task.
private enum AgendaEntry: Identifiable {
    case event(ScheduleEvent)
    case task(TodoItem)

    var id: String {
        switch self {
        case .event(let event): "event-\(event.id)"
        case .task(let item): "task-\(item.id.uuidString)"
        }
    }

    var sortDate: Date {
        switch self {
        case .event(let event): event.startDate
        case .task(let item): item.dueDate ?? .distantFuture
        }
    }
}

/// Display snapshot of an `EKEvent` with a stable identity — recurring events
/// share an `eventIdentifier`, so the occurrence start time joins the id.
private struct ScheduleEvent {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let color: Color

    init(_ event: EKEvent) {
        let start = event.startDate ?? .now
        id = "\(event.eventIdentifier ?? UUID().uuidString)-\(start.timeIntervalSinceReferenceDate)"
        title = event.title ?? "제목 없는 일정"
        startDate = start
        endDate = event.endDate
        isAllDay = event.isAllDay
        color = (event.calendar?.cgColor).map { Color(cgColor: $0) } ?? .hwangAccent
    }

    var timeText: String {
        guard !isAllDay else { return "하루 종일" }
        let start = startDate.formatted(date: .omitted, time: .shortened)
        guard let endDate else { return start }
        return "\(start) – \(endDate.formatted(date: .omitted, time: .shortened))"
    }
}

/// One upcoming day's merged entries, keyed by its day-start date.
private struct DaySection: Identifiable {
    let day: Date
    let entries: [AgendaEntry]
    var id: Date { day }
}

/// Clears List chrome so card rows sit directly on the screen background.
private extension View {
    func scheduleRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: 0, bottom: Theme.Spacing.xs, trailing: 0))
    }
}

#if DEBUG
#Preview("일정") {
    let container = SchedulePreviewData.container(seeded: true)
    ScheduleView()
        .environment(TodoRepository(context: container.mainContext))
        .environment(AppRouter())
        .modelContainer(container)
}

#Preview("빈 상태") {
    let container = SchedulePreviewData.container(seeded: false)
    ScheduleView()
        .environment(TodoRepository(context: container.mainContext))
        .environment(AppRouter())
        .modelContainer(container)
}

/// In-memory store exercising every 일정 section: 지난 할 일, 오늘, 다가오는
/// 7일, and "이후". (Calendar events depend on real EventKit access, so the
/// preview shows the permission card instead.)
private enum SchedulePreviewData {
    static func container(seeded: Bool) -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: SharedStore.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        guard seeded else { return container }
        let context = container.mainContext
        let calendar = Calendar.current
        let today9 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: .now)
        let today14 = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: .now)
        let overdue = calendar.date(byAdding: .day, value: -2, to: .now)
        let inTwoDays = calendar.date(byAdding: .day, value: 2, to: .now)
        let inFiveDays = calendar.date(byAdding: .day, value: 5, to: .now)
        let inTwoWeeks = calendar.date(byAdding: .day, value: 14, to: .now)
        let samples: [TodoItem] = [
            TodoItem(title: "지난 서류 제출", status: .active, quadrant: .urgentImportant, dueDate: overdue, source: .siri),
            TodoItem(
                title: "회의 자료 마무리", status: .active, quadrant: .urgentImportant,
                dueDate: today9, calendarEventID: "preview-event", source: .app
            ),
            TodoItem(title: "장보기", status: .active, quadrant: .urgentNotImportant, dueDate: today14, source: .homeWidget),
            TodoItem(
                title: "운동 계획 세우기", status: .active, quadrant: .importantNotUrgent,
                dueDate: inTwoDays, source: .actionButton
            ),
            TodoItem(title: "부모님 선물 준비", status: .active, quadrant: .importantNotUrgent, dueDate: inFiveDays, source: .shortcut),
            TodoItem(title: "건강검진 예약", status: .active, quadrant: .importantNotUrgent, dueDate: inTwoWeeks, source: .app),
        ]
        samples.forEach(context.insert)
        try? context.save()
        return container
    }
}
#endif
