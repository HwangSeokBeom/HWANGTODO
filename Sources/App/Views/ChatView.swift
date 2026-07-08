import HWANGTODOCore
import HWANGTODODesign
import SwiftData
import SwiftUI

/// 나와의 채팅 — 개인 생각 정리 공간 (spec §12). Entries are the user's own
/// notes, rendered as right-aligned bubbles with no bot replies. Task
/// extraction is deterministic (`ThoughtSplitter`); the UI only ever says
/// "할 일로 정리" / "추천 추출".
struct ChatView: View {
    @Environment(TodoRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @State private var convertingEntry: ChatEntry?
    @State private var toastMessage: String?
    @State private var toastToken = UUID()
    @State private var conversionTick = 0
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            entriesArea
                .background(Theme.screenBackground)
                .safeAreaInset(edge: .top, spacing: 0) { subtitleBar }
                .safeAreaInset(edge: .bottom, spacing: 0) { inputBar }
                .overlay(alignment: .top) { toastView }
                .navigationTitle("나와의 채팅")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("닫기", systemImage: "xmark") { dismiss() }
                    }
                }
                .sheet(item: $convertingEntry) { entry in
                    ConvertCandidatesSheet(entry: entry) { createdCount in
                        conversionTick += 1
                        showToast(
                            createdCount > 0
                                ? "\(createdCount)개를 \(Terminology.quickCapture)에 담았어요"
                                : "이미 정리된 내용이라 새로 담지 않았어요"
                        )
                    }
                    .presentationDetents([.medium, .large])
                }
                .sensoryFeedback(.success, trigger: conversionTick)
        }
    }

    // MARK: - Entries

    @ViewBuilder
    private var entriesArea: some View {
        if repository.chatEntries.isEmpty {
            VStack {
                Spacer()
                EmptyStateView(
                    symbol: "text.bubble",
                    title: "떠오르는 생각을 편하게 적어 보세요",
                    message: "예: 오늘 업무일지 쓰고, 캘린더 확인하고, 엄마한테 전화해야 함\n적어 둔 생각은 할 일로 정리할 수 있어요."
                )
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.m) {
                    ForEach(Array(repository.chatEntries.enumerated()), id: \.element.id) { index, entry in
                        if isFirstOfDay(at: index) {
                            dayDivider(for: entry.createdAt)
                        }
                        ChatBubbleRow(
                            entry: entry,
                            onOrganize: { convertingEntry = entry },
                            onDelete: { repository.deleteChatEntry(entry) }
                        )
                    }
                }
                .padding(Theme.Spacing.m)
            }
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    /// Day dividers appear before the first entry of each calendar day.
    private func isFirstOfDay(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let entries = repository.chatEntries
        return !Calendar.current.isDate(entries[index].createdAt, inSameDayAs: entries[index - 1].createdAt)
    }

    private func dayDivider(for date: Date) -> some View {
        Text(date.formatted(date: .abbreviated, time: .omitted))
            .font(Theme.Typography.badge)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Spacing.xs)
    }

    // MARK: - Chrome

    private var subtitleBar: some View {
        Text("생각을 적으면 할 일로 정리해 드려요")
            .font(Theme.Typography.meta)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.bottom, Theme.Spacing.xs)
            .background(Theme.screenBackground)
    }

    /// Pinned input bar — the one hero element carrying a glass surface.
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
            TextField("생각을 편하게 적어 보세요", text: $draft, axis: .vertical)
                .lineLimit(1 ... 4)
                .focused($inputFocused)
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? Color.hwangAccent : Color.secondary)
            }
            .disabled(!canSend)
            .accessibilityLabel("보내기")
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.card))
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
    }

    @ViewBuilder
    private var toastView: some View {
        if let toastMessage {
            Text(toastMessage)
                .font(Theme.Typography.meta)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, Theme.Spacing.s)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard repository.addChatEntry(draft) != nil else { return }
        draft = ""
    }

    /// Shows a transient confirmation; a newer toast cancels the older timer.
    private func showToast(_ message: String) {
        let token = UUID()
        toastToken = token
        withAnimation(.hwangSnappy) { toastMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            guard toastToken == token else { return }
            withAnimation(.hwangSnappy) { toastMessage = nil }
        }
    }
}

// MARK: - Bubble row

/// One right-aligned bubble: my own note, its time, conversion state, and the
/// "할 일로 정리" action when the splitter finds candidates.
private struct ChatBubbleRow: View {
    let entry: ChatEntry
    var onOrganize: () -> Void
    var onDelete: () -> Void

    private var candidates: [String] { ThoughtSplitter.candidates(from: entry.text) }

    var body: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: Theme.Spacing.xl)
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                Text(entry.text)
                    .font(Theme.Typography.cardTitle)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(
                        Color.hwangAccent.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    )
                    .contextMenu {
                        Button("삭제", systemImage: "trash", role: .destructive, action: onDelete)
                    }
                metaRow
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: Theme.Spacing.s) {
            if entry.hasConversions {
                Label("정리됨 \(entry.convertedTaskIDs.count)건", systemImage: "checkmark.circle.fill")
                    .font(Theme.Typography.badge)
                    .foregroundStyle(Color.hwangAccent)
            }
            Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                .font(Theme.Typography.badge)
                .foregroundStyle(.tertiary)
            if !candidates.isEmpty {
                Button(action: onOrganize) {
                    Label(Terminology.organizeIntoTasks, systemImage: "checklist")
                        .font(Theme.Typography.badge)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.mini)
                .tint(.hwangAccent)
            }
        }
    }
}

// MARK: - Conversion sheet

/// 추천 추출 결과를 고르고 다듬는 시트. All candidates start checked and each
/// title stays editable; `TodoRepository.convert` skips titles this entry
/// already produced, so re-running never duplicates.
private struct ConvertCandidatesSheet: View {
    private struct Candidate: Identifiable {
        let id = UUID()
        var text: String
        var isSelected = true
    }

    let entry: ChatEntry
    var onFinish: (Int) -> Void

    @Environment(TodoRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [Candidate]

    init(entry: ChatEntry, onFinish: @escaping (Int) -> Void) {
        self.entry = entry
        self.onFinish = onFinish
        _candidates = State(initialValue: ThoughtSplitter.candidates(from: entry.text).map { Candidate(text: $0) })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($candidates) { $candidate in
                        HStack(spacing: Theme.Spacing.s) {
                            Button {
                                withAnimation(.hwangSnappy) { candidate.isSelected.toggle() }
                            } label: {
                                Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(candidate.isSelected ? Color.hwangAccent : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(candidate.isSelected ? "빼기" : "담기")
                            TextField("할 일", text: $candidate.text)
                        }
                    }
                } header: {
                    Text("추천 추출")
                } footer: {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("고른 항목이 \(Terminology.quickCapture)에 담겨요.")
                        if entry.hasConversions {
                            Text("이미 정리한 항목은 다시 담기지 않아요.")
                        }
                    }
                }
            }
            .navigationTitle(Terminology.organizeIntoTasks)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("담기", action: convert)
                        .disabled(selectedTitles.isEmpty)
                }
            }
        }
    }

    private var selectedTitles: [String] {
        candidates.filter(\.isSelected)
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func convert() {
        let created = repository.convert(entry, titles: selectedTitles)
        onFinish(created.count)
        dismiss()
    }
}

// MARK: - Previews

#Preview("나와의 채팅") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    // In-memory preview container; failure here is programmer error.
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: SharedStore.schema, configurations: [configuration])
    let repository = TodoRepository(context: container.mainContext)
    repository.addChatEntry("오늘 업무일지 쓰고, 캘린더 확인하고, 엄마한테 전화해야 함")
    repository.addChatEntry("주말에 책 읽기")
    return ChatView()
        .environment(repository)
}

#Preview("빈 상태") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: SharedStore.schema, configurations: [configuration])
    let repository = TodoRepository(context: container.mainContext)
    return ChatView()
        .environment(repository)
}
