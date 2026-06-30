import SwiftUI

/// 채팅 — a private scratchpad for yourself. Dump messy thoughts, then extract
/// tasks deterministically. Not AI — labelled "할 일로 정리" / "추천 추출".
struct ChatView: View {
    @Environment(TaskModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var convertSheet: ChatMessage?
    @FocusState private var focused: Bool

    private let parser = ChatParser()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messages
                composer
            }
            .background(Theme.screenBackground)
            .navigationTitle("채팅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
            .sheet(item: $convertSheet) { message in
                ConvertSheet(message: message, suggestions: parser.taskTitles(from: message.text))
            }
        }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Theme.Spacing.s) {
                    if model.chat.isEmpty { intro }
                    ForEach(model.chat) { message in bubble(message).id(message.id) }
                }
                .padding(.horizontal, Theme.Spacing.m).padding(.top, Theme.Spacing.m)
            }
            .onChange(of: model.chat.count) { _, _ in
                if let last = model.chat.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private var intro: some View {
        VStack(spacing: 6) {
            Image(systemName: "bubble.left.and.bubble.right").font(.largeTitle).foregroundStyle(.secondary)
            Text("생각을 쏟아내세요").font(.headline)
            Text("떠오르는 대로 적은 뒤 할 일로 정리할 수 있어요.\n예: “오늘 업무일지 쓰고, 캘린더 확인하고, 엄마한테 전화해야 함”")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.vertical, Theme.Spacing.xl)
    }

    private func bubble(_ message: ChatMessage) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(message.text)
                .font(.body)
                .padding(.horizontal, Theme.Spacing.m).padding(.vertical, Theme.Spacing.s)
                .background(MatrixQuadrant.importantNotUrgent.accent.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .trailing)
            HStack(spacing: 10) {
                if message.isConverted {
                    Label("\(message.convertedTaskIDs.count)개 할 일", systemImage: "checkmark.circle.fill")
                        .font(.caption2).foregroundStyle(.green)
                }
                Button { convertSheet = message } label: {
                    Label("할 일로 정리", systemImage: "square.grid.2x2").font(.caption2)
                }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField("나에게 메모…", text: $draft, axis: .vertical)
                .lineLimit(1...4).focused($focused)
                .padding(.horizontal, Theme.Spacing.m).padding(.vertical, Theme.Spacing.s)
                .background(Theme.cardBackground, in: Capsule())
            Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Theme.Spacing.m).padding(.vertical, Theme.Spacing.s)
        .background(.bar)
    }

    private func send() { model.sendChat(draft); draft = "" }
}

/// Sheet to pick which extracted lines become tasks (deterministic, not AI).
private struct ConvertSheet: View {
    let message: ChatMessage
    let suggestions: [String]

    @Environment(TaskModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(suggestions, id: \.self) { title in
                        Button {
                            if selected.contains(title) { selected.remove(title) } else { selected.insert(title) }
                        } label: {
                            HStack {
                                Image(systemName: selected.contains(title) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(title) ? Color.accentColor : .secondary)
                                Text(title); Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("추천 추출")
                } footer: {
                    Text("규칙 기반으로 문장을 나눴어요. AI가 아니에요. 받은함에 추가할 항목을 고르세요.")
                }
            }
            .navigationTitle("할 일로 정리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\(selected.count)개 추가") {
                        model.convertChatMessage(message, into: suggestions.filter { selected.contains($0) })
                        dismiss()
                    }
                    .fontWeight(.semibold).disabled(selected.isEmpty)
                }
            }
            .onAppear { selected = Set(suggestions) }
        }
        .presentationDetents([.medium, .large])
    }
}
