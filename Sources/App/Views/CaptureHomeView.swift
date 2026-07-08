import HWANGTODOCore
import HWANGTODODesign
import SwiftData
import SwiftUI

/// 기록 홈 — the app's first and most important screen (spec §5).
///
/// Reads as "앱 밖에서 급하게 남긴 항목이 모이는 공간", never a generic TODO
/// list: captures from Siri, 잠금화면, 액션 버튼, 위젯, 알림 land here with
/// their true source badge, waiting to be organized later (spec §2). The
/// always-visible quick-capture accessory above the tab bar (RootTabView)
/// covers in-app entry; the toolbar button opens the option-rich 빠른 입력 sheet.
struct CaptureHomeView: View {
    @Environment(TodoRepository.self) private var repository
    @Environment(AppRouter.self) private var router

    /// Bumped once per completion — drives the success haptic.
    @State private var completionPulse = 0
    /// 지난 기록 disclosure — collapsed so 완료한 일 stays the focus (spec §4).
    @State private var showsPastRecords = false

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            List {
                todaySummary
                if !todaySources.isEmpty {
                    sourceStrip
                }

                Picker("보기", selection: $router.showCompleted) {
                    Text(Terminology.pending).tag(false)
                    Text(Terminology.completedItems).tag(true)
                }
                .pickerStyle(.segmented)
                .captureRow()

                if router.showCompleted {
                    completedContent
                } else {
                    pendingContent
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.screenBackground)
            .contentMargins(.horizontal, Theme.Spacing.m, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .refreshable { repository.reload() }
            .navigationTitle(Terminology.quickCapture)
            .navigationSubtitle(Terminology.quickCaptureSubtitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.navigate(to: .capture())
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("빠른 입력 열기")
                }
            }
            .sensoryFeedback(.success, trigger: completionPulse)
        }
    }

    // MARK: - 오늘 요약 (spec §3.2 todo mate-style 완료감)

    /// Every number comes from the shared repository APIs (`dailyProgress`,
    /// `completedToday`, `inbox`, `todayRoutines`) so home, widgets, and 일정
    /// can never disagree.
    private var todaySummary: some View {
        let progress = repository.dailyProgress()
        let ratio = progress.total > 0 ? Double(progress.done) / Double(progress.total) : 0
        let routines = repository.todayRoutines
        let routinesDone = routines.count { $0.isCompleted(on: .now) }
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("오늘 요약")
                    .font(Theme.Typography.sectionTitle)
                Spacer()
                if progress.total > 0 {
                    Text("\(progress.done)/\(progress.total)")
                        .font(Theme.Typography.meta)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: Theme.Spacing.l) {
                ZStack {
                    ProgressRing(progress: ratio, lineWidth: 6)
                    Text(progress.total > 0 ? "\(Int(ratio * 100))%" : "—")
                        .font(Theme.Typography.meta)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .frame(width: 64, height: 64)

                Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.xl, verticalSpacing: Theme.Spacing.s) {
                    GridRow {
                        counter(Terminology.todayTasks, "\(repository.todayTasks().count)")
                        counter(Terminology.completedItems, "\(repository.completedToday())")
                    }
                    GridRow {
                        counter(Terminology.pending, "\(repository.inbox.count)")
                        counter("루틴", routines.isEmpty ? "—" : "\(routinesDone)/\(routines.count)")
                    }
                }
            }
        }
        .cardSurface()
        .captureRow()
    }

    private func counter(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.Typography.number)
            Text(label)
                .font(Theme.Typography.meta)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 출처 배지 strip (spec §5)

    /// Unique sources of today's captures — quiet proof that the app collects
    /// from outside itself.
    private var todaySources: [CaptureSource] {
        let calendar = Calendar.current
        let captured = Set(
            repository.items
                .filter { calendar.isDateInToday($0.createdAt) }
                .map(\.source)
        )
        return CaptureSource.allCases.filter(captured.contains)
    }

    private var sourceStrip: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("오늘 기록이 들어온 곳")
                .font(Theme.Typography.meta)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(todaySources) { source in
                        SourceBadge(source)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .captureRow()
    }

    // MARK: - 정리 전 (spec §5)

    @ViewBuilder private var pendingContent: some View {
        if repository.inbox.isEmpty {
            EmptyStateView(
                symbol: "tray.and.arrow.down",
                title: "아직 정리할 일이 없어요",
                message: "Siri, 위젯, 액션 버튼으로 남긴 할 일이 여기에 모여요"
            )
            .captureRow()
        } else {
            ForEach(repository.inbox) { item in
                pendingRow(item)
            }
        }
    }

    private func pendingRow(_ item: TodoItem) -> some View {
        Button {
            router.presentedTaskID = item.id
        } label: {
            TaskCardView(item: item)
        }
        .buttonStyle(.plain)
        .captureRow()
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
            Button(role: .destructive) {
                withAnimation(.hwangSnappy) { repository.delete(item) }
            } label: {
                Label("삭제", systemImage: "trash")
            }
            Button {
                withAnimation(.hwangSnappy) { repository.archive(item) }
            } label: {
                // NOT "나중에 정리" — that phrase means "stay in 정리 전";
                // this action moves the item into 지난 기록.
                Label("지난 기록으로", systemImage: "archivebox")
            }
            .tint(.orange)
        }
        .contextMenu { pendingMenu(for: item) }
    }

    /// 정리는 나중에, 그러나 손 안에서 — 분면 지정과 핵심 액션을 길게 눌러 실행.
    @ViewBuilder private func pendingMenu(for item: TodoItem) -> some View {
        Section("정리하기") {
            ForEach(Quadrant.assignable) { quadrant in
                Button {
                    withAnimation(.hwangSnappy) { repository.assign(item, to: quadrant) }
                } label: {
                    Label(quadrant.title, systemImage: quadrant.symbol)
                }
            }
        }
        Section {
            Button {
                withAnimation(.hwangSnappy) { repository.moveToToday(item) }
            } label: {
                Label("오늘 하기", systemImage: "sun.max")
            }
            Button {
                withAnimation(.hwangSnappy) { _ = repository.convertToRoutine(item) }
            } label: {
                Label(Terminology.makeRoutine, systemImage: "repeat")
            }
            Button {
                router.presentedTaskID = item.id
            } label: {
                Label("자세히", systemImage: "info.circle")
            }
        }
    }

    // MARK: - 완료한 일 / 지난 기록 (spec §4)

    private var completedTodayItems: [TodoItem] {
        repository.completed.filter { item in
            item.completedAt.map { Calendar.current.isDateInToday($0) } ?? false
        }
    }

    private var completedEarlierItems: [TodoItem] {
        repository.completed.filter { item in
            !(item.completedAt.map { Calendar.current.isDateInToday($0) } ?? false)
        }
    }

    @ViewBuilder private var completedContent: some View {
        if repository.completed.isEmpty, repository.archived.isEmpty {
            EmptyStateView(
                symbol: "checkmark.circle",
                title: "아직 완료한 일이 없어요",
                message: "할 일을 완료하면 여기에 모여요"
            )
            .captureRow()
        } else {
            if !completedTodayItems.isEmpty {
                SectionHeader("오늘").captureRow()
                ForEach(completedTodayItems) { item in
                    completedRow(item)
                }
            }
            if !completedEarlierItems.isEmpty {
                SectionHeader("이전").captureRow()
                ForEach(completedEarlierItems) { item in
                    completedRow(item)
                }
            }
            if !repository.archived.isEmpty {
                pastRecordsHeader
                if showsPastRecords {
                    ForEach(repository.archived) { item in
                        archivedRow(item)
                    }
                }
            }
        }
    }

    private func completedRow(_ item: TodoItem) -> some View {
        Button {
            router.presentedTaskID = item.id
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TaskCardView(item: item)
                if let completedAt = item.completedAt {
                    Text(completedAt, format: .relative(presentation: .named))
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, Theme.Spacing.m)
                }
            }
        }
        .buttonStyle(.plain)
        .captureRow()
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation(.hwangSnappy) { repository.reopen(item) }
            } label: {
                Label("되돌리기", systemImage: "arrow.uturn.backward")
            }
            .tint(Color.hwangAccent)
        }
    }

    private var pastRecordsHeader: some View {
        Button {
            withAnimation(.hwangSnappy) { showsPastRecords.toggle() }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Text(Terminology.pastRecords)
                    .font(Theme.Typography.sectionTitle)
                Text("\(repository.archived.count)")
                    .font(Theme.Typography.meta)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(Theme.Typography.badge)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showsPastRecords ? 0 : -90))
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .captureRow()
    }

    private func archivedRow(_ item: TodoItem) -> some View {
        Button {
            router.presentedTaskID = item.id
        } label: {
            TaskCardView(item: item)
        }
        .buttonStyle(.plain)
        .captureRow()
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation(.hwangSnappy) { repository.reopen(item) }
            } label: {
                Label("복원", systemImage: "arrow.uturn.backward")
            }
            .tint(Color.hwangAccent)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation(.hwangSnappy) { repository.delete(item) }
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }
}

/// Clears List chrome so card rows sit directly on the screen background.
private extension View {
    func captureRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: 0, bottom: Theme.Spacing.xs, trailing: 0))
    }
}

#if DEBUG
#Preview("기록 홈") {
    let container = CaptureHomePreviewData.container(seeded: true)
    CaptureHomeView()
        .environment(TodoRepository(context: container.mainContext))
        .environment(AppRouter())
        .modelContainer(container)
}

#Preview("빈 상태") {
    let container = CaptureHomePreviewData.container(seeded: false)
    CaptureHomeView()
        .environment(TodoRepository(context: container.mainContext))
        .environment(AppRouter())
        .modelContainer(container)
}

/// In-memory store exercising every home section: 정리 전 captures from several
/// surfaces, 오늘/이전 completions, 지난 기록, and today's routines.
private enum CaptureHomePreviewData {
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
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)
        let samples: [TodoItem] = [
            TodoItem(title: "은행 서류 제출", source: .siri, isPinned: true),
            TodoItem(title: "장보기 목록 만들기", source: .controlCenter),
            TodoItem(title: "운동 계획 세우기", note: "주 3회 목표", source: .homeWidget),
            TodoItem(title: "책 반납하기", dueDate: today9, source: .actionButton),
            TodoItem(
                title: "회의 자료 마무리",
                status: .active,
                quadrant: .urgentImportant,
                dueDate: today9,
                calendarEventID: "preview-event",
                source: .app
            ),
            TodoItem(title: "어제 회의록 공유", status: .done, source: .app, completedAt: .now),
            TodoItem(title: "우편함 확인", status: .done, source: .notification, completedAt: yesterday),
            TodoItem(title: "옛 아이디어 정리", status: .archived, source: .selfChat, archivedAt: yesterday),
        ]
        samples.forEach(context.insert)
        let routines = [
            Routine(title: "물 마시기"),
            Routine(title: "운동하기", weekdays: [2, 4, 6]),
        ]
        routines.forEach(context.insert)
        routines.first?.toggleCompletion(on: .now)
        try? context.save()
        return container
    }
}
#endif
