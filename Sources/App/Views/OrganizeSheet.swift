import HWANGTODOCore
import HWANGTODODesign
import OSLog
import SwiftData
import SwiftUI

/// 정리하기 sheet (spec §8) — the compact triage surface for one task: 분면
/// 이동, 완료, 일정 잡기, 루틴으로 만들기, 메모 연결, 집중 시작.
///
/// Every action is explicit: the calendar event is created only on 일정 만들기,
/// the routine conversion (which removes the task) sits behind a confirm, and
/// nothing happens on open or dismiss.
struct OrganizeSheet: View {
    let item: TodoItem

    @Environment(TodoRepository.self) private var repository
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    /// 일정 잡기 discloses the date picker; confirm actually writes.
    @State private var showsScheduler = false
    @State private var scheduleDate = OrganizeSheet.nextFullHour()
    @State private var isScheduling = false
    @State private var calendarMessage: String?
    @State private var showsRoutineConfirm = false
    /// 메모 연결 opens the full task detail on top of this sheet.
    @State private var showsDetail = false
    /// Haptics: selection per quadrant move, success per completing action.
    @State private var moveTick = 0
    @State private var successTick = 0

    private static let log = Logger(subsystem: "com.hwangtodo.app", category: "OrganizeSheet")
    private static let gridColumns = [
        GridItem(.flexible(), spacing: Theme.Spacing.s),
        GridItem(.flexible(), spacing: Theme.Spacing.s),
    ]

    init(item: TodoItem) {
        self.item = item
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    header
                    quadrantSection
                    if showsScheduler {
                        schedulerCard
                    }
                    actionSection
                }
                .padding(Theme.Spacing.m)
            }
            .background(Theme.screenBackground)
            .navigationTitle("정리하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("닫기")
                }
            }
            .sheet(isPresented: $showsDetail) {
                TaskDetailView(taskID: item.id)
            }
            .confirmationDialog("루틴으로 만들까요?", isPresented: $showsRoutineConfirm, titleVisibility: .visible) {
                Button("루틴 만들기") { convertToRoutine() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 할 일은 매일 반복하는 루틴이 되고, 할 일 목록에서는 사라져요. 요일과 알림은 루틴 탭에서 바꿀 수 있어요.")
            }
            .alert(
                "캘린더 연동",
                isPresented: Binding(
                    get: { calendarMessage != nil },
                    set: { if !$0 { calendarMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(calendarMessage ?? "")
            }
            .sensoryFeedback(.selection, trigger: moveTick)
            .sensoryFeedback(.success, trigger: successTick)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(item.title)
                .font(Theme.Typography.sectionTitle)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            HStack(spacing: Theme.Spacing.xs) {
                SourceBadge(item.source)
                if item.quadrant != .unassigned {
                    QuadrantTag(item.quadrant, compact: true)
                }
                if let due = item.dueDate {
                    Label(due.formatted(.dateTime.month().day().hour().minute()), systemImage: "clock")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(.secondary)
                }
                if item.hasCalendarEvent {
                    Label("일정 연결", systemImage: "calendar")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 분면 이동 (spec §8)

    private var quadrantSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader("분면 이동")
            LazyVGrid(columns: Self.gridColumns, spacing: Theme.Spacing.s) {
                ForEach(Quadrant.assignable) { quadrant in
                    quadrantButton(quadrant)
                }
            }
        }
    }

    private func quadrantButton(_ quadrant: Quadrant) -> some View {
        let isSelected = item.quadrant == quadrant
        return Button {
            guard repository.task(withID: item.id) != nil, !isSelected else { return }
            withAnimation(.hwangSnappy) { repository.assign(item, to: quadrant) }
            moveTick += 1
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(quadrant.title, systemImage: quadrant.symbol)
                    .font(Theme.Typography.cardTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(quadrant.axisDescription)
                    .font(Theme.Typography.badge)
                    .foregroundStyle(isSelected ? quadrant.accent.opacity(0.8) : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.s)
            .background(
                isSelected ? quadrant.accent.opacity(0.14) : Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
            )
            .foregroundStyle(isSelected ? quadrant.accent : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(quadrant.title)\(isSelected ? ", 현재 분면" : "으로 이동")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - 일정 잡기 (spec §8 → §9)

    private var schedulerCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            DatePicker("날짜와 시간", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                .font(Theme.Typography.cardTitle)
            Button(action: confirmSchedule) {
                Label(
                    isScheduling ? "캘린더에 연결하는 중 …" : "캘린더에 일정 만들기",
                    systemImage: "calendar.badge.plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.hwangAccent)
            .disabled(isScheduling)
            Text("이 버튼을 눌렀을 때만 캘린더에 이벤트가 만들어져요.")
                .font(Theme.Typography.meta)
                .foregroundStyle(.tertiary)
        }
        .cardSurface()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Actions (spec §8)

    private var actionSection: some View {
        VStack(spacing: 0) {
            actionRow("완료", systemImage: "checkmark.circle.fill", tint: .green, action: complete)
            Divider().padding(.leading, Theme.Spacing.xl)
            actionRow(Terminology.scheduleIt, systemImage: "calendar.badge.plus", isOn: showsScheduler) {
                withAnimation(.hwangSnappy) { showsScheduler.toggle() }
            }
            Divider().padding(.leading, Theme.Spacing.xl)
            actionRow(Terminology.makeRoutine, systemImage: "repeat") {
                showsRoutineConfirm = true
            }
            Divider().padding(.leading, Theme.Spacing.xl)
            actionRow(Terminology.linkNote, systemImage: "note.text") {
                showsDetail = true
            }
            Divider().padding(.leading, Theme.Spacing.xl)
            actionRow(Terminology.startFocus, systemImage: "play.fill", tint: Color.hwangAccent, action: startFocus)
        }
        .cardSurface(padding: 0)
    }

    private func actionRow(
        _ title: String,
        systemImage: String,
        tint: Color = .primary,
        isOn: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: systemImage)
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(isOn ? Color.hwangAccent : tint)
                    .frame(width: 28)
                Text(title)
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(isOn ? Color.hwangAccent : Color.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(Theme.Typography.badge)
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func complete() {
        guard let live = repository.task(withID: item.id), live.isOpen else { return }
        withAnimation(.hwangSnappy) { repository.markDone(live) }
        successTick += 1
        dismiss()
    }

    private func confirmSchedule() {
        guard !isScheduling else { return }
        guard repository.task(withID: item.id) != nil else {
            dismiss()
            return
        }
        isScheduling = true
        Task {
            defer { isScheduling = false }
            do {
                try await CalendarService.shared.scheduleEvent(for: item, at: scheduleDate, repository: repository)
                successTick += 1
                dismiss()
            } catch {
                Self.log.error("schedule from organize sheet failed: \(error, privacy: .public)")
                calendarMessage = error.localizedDescription
            }
        }
    }

    /// Conversion removes the task (it lives on as the routine) — reached only
    /// through the explicit confirm dialog above.
    private func convertToRoutine() {
        guard repository.task(withID: item.id) != nil else {
            dismiss()
            return
        }
        repository.convertToRoutine(item)
        successTick += 1
        dismiss()
    }

    private func startFocus() {
        guard let live = repository.task(withID: item.id), live.isOpen else { return }
        FocusSessionManager.shared.start(queue: [live])
        successTick += 1
        dismiss()
        // The 집중 sheet is presented by RootTabView; requesting it while this
        // sheet is still animating away gets dropped, so hand off after the
        // dismissal transition completes.
        let router = self.router
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            router.presentedSheet = .focus
        }
    }

    /// The next :00 o'clock — same default slot as `CalendarService`.
    private static func nextFullHour(calendar: Calendar = .current, now: Date = .now) -> Date {
        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        return hourStart.addingTimeInterval(3600)
    }
}

#if DEBUG
#Preview("정리하기") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: SharedStore.schema, configurations: [configuration])
    let repository = TodoRepository(context: container.mainContext)
    let item = repository.capture("회의 자료 마무리해서 팀에 공유", source: .siri)
    if let item {
        repository.assign(item, to: .urgentImportant)
    }
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            if let item {
                OrganizeSheet(item: item)
            }
        }
        .environment(repository)
        .environment(AppRouter())
        .modelContainer(container)
}
#endif
