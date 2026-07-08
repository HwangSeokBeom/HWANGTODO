import HWANGTODOCore
import HWANGTODODesign
import SwiftData
import SwiftUI

/// 빠른 입력 sheet (spec §5) — router-presented so widgets, controls, and
/// notifications deep-link straight into a focused keyboard. Options (오늘/내일,
/// 분면, 메모) are strictly optional: capture never demands a decision (spec §2).
/// Saving keeps the sheet open by default (계속 기록) for back-to-back entry.
struct CaptureSheetView: View {
    @Environment(TodoRepository.self) private var repository
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var showsNoteField = false
    @State private var due: DueChoice = .none
    @State private var quadrant: Quadrant = .unassigned
    /// 저장 후에도 시트를 열어 두는 연속 기록 모드 — 기본 켜짐.
    @AppStorage("captureSheetKeepOpen") private var keepOpen = true
    @State private var showsSavedBadge = false
    /// Bumped once per successful save — drives the haptic and 저장됨 badge.
    @State private var saveCount = 0
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    titleField
                    optionChips
                    if showsNoteField {
                        noteField
                    }
                    keepOpenToggle
                }
                .padding(Theme.Spacing.m)
            }
            .background(Theme.screenBackground)
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle(Terminology.quickCapture)
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
            .onAppear { titleFocused = true }
            .onChange(of: router.captureFocusToken) { titleFocused = true }
            .task(id: saveCount) { await revealSavedBadge() }
            .sensoryFeedback(.success, trigger: saveCount)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Fields

    private var titleField: some View {
        TextField(Terminology.quickCapturePlaceholder, text: $title)
            .font(Theme.Typography.sectionTitle)
            .focused($titleFocused)
            .submitLabel(.done)
            .onSubmit(save)
            .padding(Theme.Spacing.m)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var noteField: some View {
        TextField("메모 남기기", text: $note, axis: .vertical)
            .lineLimit(2 ... 4)
            .padding(Theme.Spacing.m)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Quick options (모두 선택 사항)

    private var optionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                optionChip("오늘", systemImage: "sun.max", isOn: due == .today) {
                    due = due == .today ? .none : .today
                }
                optionChip("내일", systemImage: "sunrise", isOn: due == .tomorrow) {
                    due = due == .tomorrow ? .none : .tomorrow
                }
                quadrantMenu
                optionChip("메모", systemImage: "note.text", isOn: showsNoteField) {
                    withAnimation(.hwangSnappy) { showsNoteField.toggle() }
                }
            }
        }
    }

    private var quadrantMenu: some View {
        Menu {
            Picker("분면 선택", selection: $quadrant) {
                Label(Terminology.organizeLater, systemImage: Quadrant.unassigned.symbol)
                    .tag(Quadrant.unassigned)
                ForEach(Quadrant.assignable) { choice in
                    Label(choice.title, systemImage: choice.symbol)
                        .tag(choice)
                }
            }
        } label: {
            chipLabel(
                quadrant == .unassigned ? Terminology.organizeLater : quadrant.title,
                systemImage: quadrant.symbol,
                isOn: quadrant != .unassigned
            )
        }
        .accessibilityLabel("분면 선택")
    }

    private func optionChip(
        _ text: String,
        systemImage: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            chipLabel(text, systemImage: systemImage, isOn: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func chipLabel(_ text: String, systemImage: String, isOn: Bool) -> some View {
        Label(text, systemImage: systemImage)
            .font(Theme.Typography.meta)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isOn ? Color.hwangAccent.opacity(0.15) : Color(.tertiarySystemFill), in: Capsule())
            .foregroundStyle(isOn ? Color.hwangAccent : Color.secondary)
    }

    private var keepOpenToggle: some View {
        Toggle(isOn: $keepOpen) {
            VStack(alignment: .leading, spacing: 2) {
                Text("계속 기록")
                    .font(Theme.Typography.cardTitle)
                Text("저장한 뒤에도 입력창을 열어 둬요")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color.hwangAccent)
    }

    // MARK: - Save

    private var saveBar: some View {
        VStack(spacing: Theme.Spacing.s) {
            if showsSavedBadge {
                Label("저장됨", systemImage: "checkmark.circle.fill")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Color.hwangAccent)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            Button(action: save) {
                Text("저장")
                    .font(Theme.Typography.cardTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.hwangAccent)
            .disabled(trimmedTitle.isEmpty)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(.bar)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        // The sheet may have been opened BY a system surface (제어센터 control,
        // 잠금화면/홈 위젯 deep link) — badge that surface, not "앱" (spec §5).
        let saved = repository.capture(
            title,
            source: router.pendingCaptureSource ?? .app,
            quadrant: quadrant,
            dueDate: due.date,
            note: showsNoteField ? note : nil
        )
        guard saved != nil else { return }
        saveCount += 1
        guard keepOpen else {
            dismiss()
            return
        }
        title = ""
        note = ""
        due = .none
        quadrant = .unassigned
        titleFocused = true
    }

    /// 저장됨 badge: appears per save, then quietly fades. Restarting the task
    /// on rapid saves cancels the previous fade instead of stacking timers.
    private func revealSavedBadge() async {
        guard saveCount > 0 else { return }
        withAnimation(.hwangSnappy) { showsSavedBadge = true }
        try? await Task.sleep(for: .seconds(1.5))
        guard !Task.isCancelled else { return }
        withAnimation(.hwangSnappy) { showsSavedBadge = false }
    }

    /// 오늘/내일 quick-due chips — 9시 고정, `TodoRepository.moveToToday`와
    /// 같은 규칙이라 화면마다 시간이 어긋나지 않는다.
    private enum DueChoice: Hashable {
        case none, today, tomorrow

        var date: Date? {
            let calendar = Calendar.current
            switch self {
            case .none:
                return nil
            case .today:
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: .now)
            case .tomorrow:
                guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) else { return nil }
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
            }
        }
    }
}

#if DEBUG
#Preview("빠른 입력") {
    let container = try! ModelContainer(
        for: SharedStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )
    CaptureSheetView()
        .environment(TodoRepository(context: container.mainContext))
        .environment(AppRouter())
        .modelContainer(container)
}
#endif
