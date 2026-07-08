import HWANGTODOCore
import HWANGTODODesign
import OSLog
import SwiftData
import SwiftUI
import UIKit

/// 할 일 상세 — the one place where a captured task gets organized: 제목, 정리
/// (분면·우선순위), 일정 (날짜·알림·캘린더 연동, spec §9), 메모 (spec §11), and
/// the spec §8 actions. Resolves the task by id so a deep link to a deleted
/// task degrades to a quiet empty state instead of crashing.
struct TaskDetailView: View {
    let taskID: UUID

    @Environment(TodoRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let item = repository.task(withID: taskID) {
                    TaskDetailForm(item: item)
                } else {
                    EmptyStateView(
                        symbol: "questionmark.circle",
                        title: "삭제된 할 일이에요",
                        message: "이미 삭제되었거나 찾을 수 없는 할 일이에요."
                    )
                }
            }
            .navigationTitle("할 일")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Form

/// The editable body for a resolved task. Text fields commit on submit and on
/// focus loss — never per keystroke, since every repository write persists and
/// reloads widget timelines.
private struct TaskDetailForm: View {
    let item: TodoItem

    @Environment(TodoRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var title: String
    @State private var noteText: String
    @State private var linkText: String
    @State private var isLinkingCalendar = false
    @State private var calendarIssue: CalendarIssue?
    @State private var showRoutineSheet = false
    @State private var showDeleteConfirm = false
    @State private var completionTick = 0
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case title, note, link }

    private enum CalendarIssue: Equatable {
        case accessDenied
        case scheduleFailed(String)

        var message: String {
            switch self {
            case .accessDenied:
                "캘린더 권한이 꺼져 있어요. 설정에서 캘린더 접근을 허용하면 일정을 만들 수 있어요."
            case .scheduleFailed(let reason):
                "캘린더에 일정을 만들지 못했어요.\n\(reason)"
            }
        }
    }

    private static let log = Logger(subsystem: "com.hwangtodo.app", category: "TaskDetail")
    private static let quadrantChoices: [Quadrant] = Quadrant.assignable + [.unassigned]

    init(item: TodoItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _noteText = State(initialValue: item.note ?? "")
        _linkText = State(initialValue: item.noteLinkURL ?? "")
    }

    var body: some View {
        Form {
            titleSection
            organizeSection
            scheduleSection
            noteSection
            actionSection
            infoSection
        }
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: completionTick)
        .onChange(of: focusedField) { oldValue, _ in
            switch oldValue {
            case .title: commitTitle()
            case .note, .link: commitNote()
            case nil: break
            }
        }
        .onDisappear {
            commitTitle()
            commitNote()
        }
        .task { CalendarService.shared.refreshStatus() }
        .sheet(isPresented: $showRoutineSheet) {
            RoutineWeekdaySheet(item: item) { dismiss() }
                .presentationDetents([.medium])
        }
        .confirmationDialog("이 할 일을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                repository.delete(item)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제하면 되돌릴 수 없어요.")
        }
        .alert(
            "캘린더 연동",
            isPresented: Binding(
                get: { calendarIssue != nil },
                set: { if !$0 { calendarIssue = nil } }
            )
        ) {
            if calendarIssue == .accessDenied {
                Button("설정 열기", action: openAppSettings)
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text(calendarIssue?.message ?? "")
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section {
            TextField("할 일 제목", text: $title)
                .font(Theme.Typography.cardTitle)
                .focused($focusedField, equals: .title)
                .submitLabel(.done)
                .onSubmit(commitTitle)
            LabeledContent("상태") {
                HStack(spacing: Theme.Spacing.xs) {
                    if item.quadrant != .unassigned {
                        QuadrantTag(item.quadrant, compact: true)
                    }
                    Text(item.status.label)
                }
            }
            if item.status == .done, let completedAt = item.completedAt {
                LabeledContent("완료한 시각", value: completedAt.formatted(date: .abbreviated, time: .shortened))
            }
            Toggle(isOn: pinnedBinding) {
                Label("맨 위에 고정", systemImage: "pin")
            }
        }
    }

    private var organizeSection: some View {
        Section {
            Picker(selection: quadrantBinding) {
                ForEach(Self.quadrantChoices) { quadrant in
                    Label(quadrant.title, systemImage: quadrant.symbol).tag(quadrant)
                }
            } label: {
                Text("정리 위치")
            }
            Picker("우선순위", selection: priorityBinding) {
                ForEach(TaskPriority.allCases) { priority in
                    Text(priority.label).tag(priority)
                }
            }
        } header: {
            Text(Terminology.tabOrganize)
        } footer: {
            Text(item.quadrant.axisDescription)
        }
    }

    private var scheduleSection: some View {
        Section(Terminology.tabSchedule) {
            Toggle(isOn: dueEnabledBinding) {
                Label(Terminology.scheduleIt, systemImage: "calendar")
            }
            if item.dueDate != nil {
                DatePicker("날짜와 시간", selection: dueDateBinding, displayedComponents: [.date, .hourAndMinute])
            }
            Toggle(isOn: reminderEnabledBinding) {
                Label("알림 받기", systemImage: "bell")
            }
            if item.reminderDate != nil {
                DatePicker("알림 시각", selection: reminderDateBinding, displayedComponents: [.date, .hourAndMinute])
            }
            calendarRows
        }
    }

    /// Apple Calendar 연동 (spec §9): honest link state, orphan detection when
    /// the event was deleted outside the app, and graceful permission flow.
    @ViewBuilder
    private var calendarRows: some View {
        if item.hasCalendarEvent {
            LabeledContent {
                Text("연결됨")
                    .font(Theme.Typography.badge)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.hwangAccent.opacity(0.14), in: Capsule())
                    .foregroundStyle(Color.hwangAccent)
            } label: {
                Label("캘린더", systemImage: "calendar.badge.checkmark")
            }
            if !CalendarService.shared.linkedEventExists(item) {
                Label("캘린더에서 삭제된 일정이에요", systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.orange)
            }
            Button("연결 해제", role: .destructive) {
                CalendarService.shared.unlinkEvent(for: item, repository: repository)
            }
        } else {
            Button(action: linkToCalendar) {
                Label(
                    isLinkingCalendar ? "캘린더에 연결하는 중 …" : "캘린더에 일정 만들기",
                    systemImage: "calendar.badge.plus"
                )
            }
            .disabled(isLinkingCalendar)
        }
    }

    private var noteSection: some View {
        Section {
            TextEditor(text: $noteText)
                .frame(minHeight: 96)
                .focused($focusedField, equals: .note)
                .overlay(alignment: .topLeading) {
                    if noteText.isEmpty {
                        Text("업무일지, 회의 메모, 아이디어, 배경 설명 …")
                            .foregroundStyle(.tertiary)
                            .padding(.top, Theme.Spacing.s)
                            .allowsHitTesting(false)
                    }
                }
            HStack(spacing: Theme.Spacing.s) {
                TextField("외부 메모 링크 붙여넣기", text: $linkText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .link)
                if let url = externalLinkURL {
                    Link(destination: url) {
                        Label("열기", systemImage: "arrow.up.forward.app")
                    }
                    .font(Theme.Typography.meta)
                }
            }
        } header: {
            Text(Terminology.linkNote)
        } footer: {
            Text("Apple Notes 내용은 앱이 읽을 수 없어요. 링크로 열기만 지원해요.")
        }
    }

    private var actionSection: some View {
        Section {
            Button(action: toggleDone) {
                Label(
                    item.isOpen ? "완료" : "되돌리기",
                    systemImage: item.isOpen ? "checkmark.circle.fill" : "arrow.uturn.backward"
                )
            }
            Button {
                showRoutineSheet = true
            } label: {
                Label(Terminology.makeRoutine, systemImage: "repeat")
            }
            if item.status != .archived {
                Button {
                    repository.archive(item)
                    dismiss()
                } label: {
                    // NOT "나중에 정리" (= stay in 정리 전) — this archives.
                    Label("지난 기록으로", systemImage: "archivebox")
                }
            }
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    /// 언제 어디서 기록됐는지 — the honest capture-source footer (spec §5).
    private var infoSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.s) {
                SourceBadge(item.source)
                Text("\(item.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(item.source.label)에서 기록")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Bindings (write-through to the repository)

    private var pinnedBinding: Binding<Bool> {
        Binding(
            get: { item.isPinned },
            set: { newValue in
                guard newValue != item.isPinned else { return }
                repository.togglePin(item)
            }
        )
    }

    private var quadrantBinding: Binding<Quadrant> {
        Binding(get: { item.quadrant }, set: { repository.assign(item, to: $0) })
    }

    private var priorityBinding: Binding<TaskPriority> {
        Binding(get: { item.priority }, set: { repository.setPriority(item, $0) })
    }

    private var dueEnabledBinding: Binding<Bool> {
        Binding(
            get: { item.dueDate != nil },
            set: { enabled in repository.schedule(item, at: enabled ? Self.defaultPickerDate() : nil) }
        )
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { item.dueDate ?? Self.defaultPickerDate() },
            set: { repository.schedule(item, at: $0) }
        )
    }

    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { item.reminderDate != nil },
            set: { enabled in
                // Seed with the due date only while it is still in the future —
                // a past date would show an ON toggle for a reminder that can
                // never fire.
                let seed = item.dueDate.flatMap { $0 > .now ? $0 : nil } ?? Self.defaultPickerDate()
                repository.setReminder(item, at: enabled ? seed : nil)
            }
        )
    }

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: { item.reminderDate ?? Self.defaultPickerDate() },
            set: { repository.setReminder(item, at: $0) }
        )
    }

    /// Next full hour — a sensible starting point when a picker turns on.
    private static func defaultPickerDate(calendar: Calendar = .current, now: Date = .now) -> Date {
        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        return hourStart.addingTimeInterval(3600)
    }

    // MARK: - Commits

    /// Guards protect against writes after deletion (e.g. onDisappear racing
    /// a delete) — mutating a removed model would corrupt the save.
    private func commitTitle() {
        guard repository.task(withID: item.id) != nil else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            title = item.title
            return
        }
        guard trimmed != item.title else { return }
        repository.setTitle(item, trimmed)
    }

    private func commitNote() {
        guard repository.task(withID: item.id) != nil else { return }
        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard note != (item.note ?? "") || link != (item.noteLinkURL ?? "") else { return }
        repository.setNote(item, text: noteText, linkURL: linkText)
    }

    // MARK: - Actions

    private var externalLinkURL: URL? {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme?.isEmpty == false else { return nil }
        return url
    }

    private func toggleDone() {
        if item.isOpen {
            repository.markDone(item)
            completionTick += 1
        } else {
            repository.reopen(item)
        }
    }

    private func linkToCalendar() {
        guard !isLinkingCalendar else { return }
        isLinkingCalendar = true
        Task {
            defer { isLinkingCalendar = false }
            if CalendarService.shared.accessState == .needsSetup {
                guard await CalendarService.shared.requestAccess() else {
                    calendarIssue = .accessDenied
                    return
                }
            } else if CalendarService.shared.accessState == .denied {
                calendarIssue = .accessDenied
                return
            }
            do {
                try await CalendarService.shared.scheduleEvent(for: item, at: item.dueDate, repository: repository)
            } catch {
                Self.log.error("calendar link failed: \(error, privacy: .public)")
                calendarIssue = .scheduleFailed(error.localizedDescription)
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Routine conversion

/// Minimal weekday pre-pick before converting a task into a routine
/// (spec §10 — fast and simple, no repeat machinery). Empty selection means
/// every day. Conversion removes the source task, so the caller must dismiss.
private struct RoutineWeekdaySheet: View {
    let item: TodoItem
    var onConverted: () -> Void

    @Environment(TodoRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWeekdays: Set<Int> = []

    /// `Calendar` weekday numbering: 1 = 일요일 … 7 = 토요일.
    private static let weekdayNames = ["", "일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                Text(item.title)
                    .font(Theme.Typography.cardTitle)
                    .multilineTextAlignment(.center)
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(1 ... 7, id: \.self) { day in
                        weekdayButton(day)
                    }
                }
                VStack(spacing: Theme.Spacing.xs) {
                    Text(cycleDescription)
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.secondary)
                    Text("요일을 고르지 않으면 매일 반복해요.")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Theme.Spacing.l)
            .background(Theme.screenBackground)
            .navigationTitle(Terminology.makeRoutine)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("루틴 만들기") {
                        repository.convertToRoutine(item, weekdays: selectedWeekdays.sorted())
                        onConverted()
                    }
                }
            }
        }
    }

    private var cycleDescription: String {
        guard !selectedWeekdays.isEmpty else { return "매일 반복" }
        return selectedWeekdays.sorted().map { Self.weekdayNames[$0] }.joined(separator: "·") + "요일 반복"
    }

    private func weekdayButton(_ day: Int) -> some View {
        let isSelected = selectedWeekdays.contains(day)
        return Button {
            withAnimation(.hwangSnappy) {
                if isSelected {
                    selectedWeekdays.remove(day)
                } else {
                    selectedWeekdays.insert(day)
                }
            }
        } label: {
            Text(Self.weekdayNames[day])
                .font(Theme.Typography.cardTitle)
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.vertical, Theme.Spacing.s)
                .background(isSelected ? Color.hwangAccent : Color(.tertiarySystemFill), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Self.weekdayNames[day])요일")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

#Preview("할 일 상세") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    // In-memory preview container; failure here is programmer error.
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: SharedStore.schema, configurations: [configuration])
    let repository = TodoRepository(context: container.mainContext)
    let item = repository.capture("회의 자료 마무리해서 팀에 공유", source: .siri)
    if let item {
        repository.assign(item, to: .urgentImportant)
        repository.schedule(item, at: .now)
        repository.setNote(item, text: "슬라이드 3장 보완한 뒤 공유하기", linkURL: nil)
    }
    return TaskDetailView(taskID: item?.id ?? UUID())
        .environment(repository)
}

#Preview("삭제된 할 일") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: SharedStore.schema, configurations: [configuration])
    let repository = TodoRepository(context: container.mainContext)
    return TaskDetailView(taskID: UUID())
        .environment(repository)
}
