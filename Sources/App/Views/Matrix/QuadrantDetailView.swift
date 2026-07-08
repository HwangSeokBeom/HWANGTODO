import HWANGTODOCore
import HWANGTODODesign
import OSLog
import SwiftData
import SwiftUI

/// One quadrant's task list with its spec §8 hero action: 지금 하기(집중 시작),
/// 일정 잡기(캘린더 이벤트), 맡기기(맡김 메모), 줄이기(지난 기록으로).
///
/// The hero targets the quadrant's representative (topmost) task and always
/// says which task it will touch — no hidden side effects. Row taps open the
/// compact `OrganizeSheet`; swipe completes; the context menu moves between
/// quadrants.
struct QuadrantDetailView: View {
    let quadrant: Quadrant

    @Environment(TodoRepository.self) private var repository
    @Environment(AppRouter.self) private var router

    /// Row tapped → compact triage sheet.
    @State private var organizingItem: TodoItem?
    /// 일정 잡기 hero → explicit date confirm sheet.
    @State private var schedulingItem: TodoItem?
    /// 맡기기 hero → 맡김 메모 sheet.
    @State private var delegatingItem: TodoItem?
    /// 줄이기 hero → archive confirm.
    @State private var reducingItem: TodoItem?
    /// Bumped once per completion — drives the success haptic.
    @State private var completionPulse = 0

    var body: some View {
        List {
            if tasks.isEmpty {
                EmptyStateView(
                    symbol: quadrant.symbol,
                    title: "\(quadrant.title)이 비어 있어요",
                    message: "기록 화면의 정리 전 항목을 길게 눌러 이 분면으로 옮길 수 있어요"
                )
                .organizeRow()
            } else {
                heroCard.organizeRow()
                ForEach(tasks) { item in
                    row(item)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.screenBackground)
        .contentMargins(.horizontal, Theme.Spacing.m, for: .scrollContent)
        .navigationTitle(quadrant.title)
        .navigationSubtitle(quadrant.axisDescription)
        .sheet(item: $organizingItem) { item in
            OrganizeSheet(item: item)
        }
        .sheet(item: $schedulingItem) { item in
            ScheduleDateSheet(item: item)
        }
        .sheet(item: $delegatingItem) { item in
            DelegateNoteSheet(item: item)
        }
        .confirmationDialog(
            "지난 기록으로 옮길까요?",
            isPresented: reduceConfirmPresented,
            titleVisibility: .visible,
            presenting: reducingItem
        ) { item in
            Button("줄이기", role: .destructive) {
                withAnimation(.hwangSnappy) { repository.archive(item) }
            }
            Button("취소", role: .cancel) {}
        } message: { item in
            Text("'\(item.title)' 항목이 지난 기록으로 이동해요. 언제든 되돌릴 수 있어요.")
        }
        .sensoryFeedback(.success, trigger: completionPulse)
    }

    private var tasks: [TodoItem] { repository.tasks(in: quadrant) }

    /// `confirmationDialog(isPresented:presenting:)` bridge for `reducingItem`.
    private var reduceConfirmPresented: Binding<Bool> {
        Binding(
            get: { reducingItem != nil },
            set: { if !$0 { reducingItem = nil } }
        )
    }

    // MARK: - Hero action (spec §8)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button(action: performHeroAction) {
                Label(quadrant.actionLabel, systemImage: quadrant.symbol)
                    .font(Theme.Typography.cardTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(quadrant.accent)
            if let hint = heroHint {
                Text(hint)
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    /// Says exactly what the hero will do, to which task.
    private var heroHint: String? {
        guard let top = tasks.first else { return nil }
        switch quadrant {
        case .urgentImportant:
            return "\(quadrant.title) \(tasks.count)개로 집중을 시작해요"
        case .importantNotUrgent:
            return "'\(top.title)'을 캘린더 일정으로 만들어요"
        case .urgentNotImportant:
            return "'\(top.title)'에 맡김 메모를 남겨요"
        case .notUrgentNotImportant:
            return "'\(top.title)'을 지난 기록으로 옮겨요"
        case .unassigned:
            return nil
        }
    }

    private func performHeroAction() {
        guard let top = tasks.first else { return }
        switch quadrant {
        case .urgentImportant:
            FocusSessionManager.shared.start(queue: tasks)
            router.presentedSheet = .focus
        case .importantNotUrgent:
            schedulingItem = top
        case .urgentNotImportant:
            delegatingItem = top
        case .notUrgentNotImportant:
            reducingItem = top
        case .unassigned:
            break
        }
    }

    // MARK: - Rows

    private func row(_ item: TodoItem) -> some View {
        Button {
            organizingItem = item
        } label: {
            TaskCardView(item: item)
        }
        .buttonStyle(.plain)
        .organizeRow()
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation(.hwangSnappy) { repository.markDone(item) }
                completionPulse += 1
            } label: {
                Label("완료", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .contextMenu {
            Section("분면 이동") {
                ForEach(Quadrant.assignable.filter { $0 != quadrant }) { destination in
                    Button {
                        withAnimation(.hwangSnappy) { repository.assign(item, to: destination) }
                    } label: {
                        Label(destination.title, systemImage: destination.symbol)
                    }
                }
            }
            Section {
                Button {
                    organizingItem = item
                } label: {
                    Label("정리하기", systemImage: "slider.horizontal.3")
                }
            }
        }
    }
}

/// Clears List chrome so card rows sit directly on the screen background.
private extension View {
    func organizeRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: 0, bottom: Theme.Spacing.xs, trailing: 0))
    }
}

// MARK: - 일정 잡기 (spec §8 → §9)

/// Explicit date confirm before touching Apple Calendar: the event is created
/// only when the user taps 일정 만들기 — never as a side effect of opening
/// the sheet.
private struct ScheduleDateSheet: View {
    let item: TodoItem

    @Environment(TodoRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let log = Logger(subsystem: "com.hwangtodo.app", category: "ScheduleDateSheet")

    init(item: TodoItem) {
        self.item = item
        _date = State(initialValue: item.dueDate ?? Self.nextFullHour())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(item.title)
                        .font(Theme.Typography.cardTitle)
                    DatePicker("날짜와 시간", selection: $date, displayedComponents: [.date, .hourAndMinute])
                } footer: {
                    Text("일정 만들기를 누르면 캘린더에 1시간짜리 이벤트가 만들어지고, 이 할 일과 연결돼요.")
                }
            }
            .navigationTitle(Terminology.scheduleIt)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "만드는 중 …" : "일정 만들기", action: confirm)
                        .disabled(isSaving)
                }
            }
            .alert(
                "캘린더 연동",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func confirm() {
        guard !isSaving else { return }
        // The item may have been deleted from another screen while this sheet
        // was open — writing to a removed model would corrupt the save.
        guard repository.task(withID: item.id) != nil else {
            dismiss()
            return
        }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await CalendarService.shared.scheduleEvent(for: item, at: date, repository: repository)
                dismiss()
            } catch {
                Self.log.error("schedule from quadrant failed: \(error, privacy: .public)")
                errorMessage = error.localizedDescription
            }
        }
    }

    /// The next :00 o'clock — same default slot as `CalendarService`.
    private static func nextFullHour(calendar: Calendar = .current, now: Date = .now) -> Date {
        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        return hourStart.addingTimeInterval(3600)
    }
}

// MARK: - 맡기기 (spec §8)

/// 맡기기 leaves an explicit 맡김 메모 on the task (who/how) through
/// `repository.setNote` — the task stays open in its quadrant.
private struct DelegateNoteSheet: View {
    let item: TodoItem

    @Environment(TodoRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var hint = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(item.title)
                        .font(Theme.Typography.cardTitle)
                    TextField("누구에게, 어떻게 맡길까요?", text: $hint, axis: .vertical)
                        .lineLimit(2 ... 4)
                        .focused($fieldFocused)
                } footer: {
                    Text("맡김 메모는 할 일 상세의 메모에 함께 남아요.")
                }
            }
            .navigationTitle(Quadrant.urgentNotImportant.actionLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("메모 남기기", action: confirm)
                        .disabled(hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { fieldFocused = true }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func confirm() {
        guard repository.task(withID: item.id) != nil else {
            dismiss()
            return
        }
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Append below any existing note instead of overwriting it.
        let merged = [item.note, "맡기기: \(trimmed)"]
            .compactMap { $0 }
            .joined(separator: "\n")
        repository.setNote(item, text: merged, linkURL: item.noteLinkURL)
        dismiss()
    }
}

#if DEBUG
#Preview("지금 할 일") {
    let container = QuadrantDetailPreviewData.container()
    NavigationStack {
        QuadrantDetailView(quadrant: .urgentImportant)
    }
    .environment(TodoRepository(context: container.mainContext))
    .environment(AppRouter())
    .modelContainer(container)
}

#Preview("빈 분면") {
    let container = QuadrantDetailPreviewData.container()
    NavigationStack {
        QuadrantDetailView(quadrant: .notUrgentNotImportant)
    }
    .environment(TodoRepository(context: container.mainContext))
    .environment(AppRouter())
    .modelContainer(container)
}

private enum QuadrantDetailPreviewData {
    static func container() -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: SharedStore.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let samples: [TodoItem] = [
            TodoItem(title: "회의 자료 마무리", status: .active, quadrant: .urgentImportant, source: .siri, isPinned: true),
            TodoItem(title: "세금 신고 준비", status: .active, quadrant: .urgentImportant, source: .homeWidget),
            TodoItem(title: "은행 서류 제출", status: .active, quadrant: .urgentImportant, source: .actionButton),
        ]
        samples.forEach(context.insert)
        try? context.save()
        return container
    }
}
#endif
