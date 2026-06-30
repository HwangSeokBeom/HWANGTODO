import SwiftUI

/// 받은함 — the home. Everything captured from any surface lands here. Capture-first:
/// a one-line capture bar sits on top, a daily-clarity strip shows today's progress,
/// then the unsorted captures as glanceable cards.
struct InboxView: View {
    @Environment(TaskModel.self) private var model
    @Environment(AppRouter.self) private var router

    @State private var captureText = ""
    @State private var organizeTask: MatrixTask?
    @State private var showArchive = false
    @FocusState private var captureFocused: Bool

    private var items: [MatrixTask] { showArchive ? model.archived : model.inbox }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    if !showArchive {
                        captureBar
                        todayClarity
                        if !model.inbox.isEmpty { hint }
                    }
                    cards
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.s)
            }
            .background(Theme.screenBackground)
            .navigationTitle(showArchive ? "보관함" : "받은함")
            .tabBarSafeBottomPadding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("보기", selection: $showArchive) {
                        Text("받은함").tag(false); Text("보관함").tag(true)
                    }.pickerStyle(.segmented).frame(width: 150)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { router.presentedSheet = .chat } label: { Image(systemName: "bubble.left.and.bubble.right") }
                    Button { router.presentedSheet = .focus } label: { Image(systemName: "timer") }
                }
            }
            .sheet(item: $organizeTask) { OrganizeSheet(task: $0) }
            .onChange(of: router.captureFocusToken) { _, _ in captureFocused = true }
        }
    }

    // MARK: - Capture bar

    private var captureBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "plus.circle.fill").foregroundStyle(.secondary)
            TextField("빠르게 기록하기", text: $captureText)
                .submitLabel(.done)
                .focused($captureFocused)
                .onSubmit(quickCapture)
            if !captureText.isEmpty {
                Button("추가", action: quickCapture).font(.subheadline.weight(.semibold))
            }
        }
        .cardSurface()
    }

    private func quickCapture() {
        model.capture(captureText, source: .app)
        captureText = ""
        captureFocused = true
    }

    // MARK: - Daily clarity (todo mate–style)

    private var todayClarity: some View {
        let progress = model.dailyProgress()
        let ratio = progress.total == 0 ? 0 : Double(progress.done) / Double(progress.total)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("오늘").font(.headline)
                Spacer()
                Text(progress.total == 0 ? "오늘 항목 없음" : "\(progress.done)/\(progress.total) 완료")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ProgressView(value: ratio)
                .tint(MatrixQuadrant.importantNotUrgent.accent)
            HStack(spacing: Theme.Spacing.m) {
                clarityChip("받은함", model.inbox.count, "tray", DeepLink.inbox)
                clarityChip("지금 할 일", model.count(in: .urgentImportant), "bolt.fill", DeepLink.quadrant(.urgentImportant))
                clarityChip("오늘 루틴", model.todayRoutines.count, "repeat", DeepLink.routine)
            }
        }
        .cardSurface()
    }

    private func clarityChip(_ title: String, _ count: Int, _ icon: String, _ link: URL) -> some View {
        Button { router.handle(url: link) } label: {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: icon).font(.caption2)
                    Text("\(count)").font(.headline).monospacedDigit()
                }
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var hint: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(MatrixQuadrant.importantNotUrgent.accent)
            Text("아직 정리하지 않은 할 일이 있어요. 탭해서 정리해 보세요.")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private var cards: some View {
        if items.isEmpty {
            emptyState
        } else {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(items) { task in
                    TaskCardView(task: task, showQuadrant: showArchive)
                        .onTapGesture { organizeTask = task }
                        .contextMenu { contextActions(task) }
                }
            }
        }
    }

    @ViewBuilder
    private func contextActions(_ task: MatrixTask) -> some View {
        if showArchive {
            Button { model.restore(task) } label: { Label("복원", systemImage: "arrow.uturn.backward") }
            Button(role: .destructive) { model.delete(task) } label: { Label("삭제", systemImage: "trash") }
        } else {
            Button { model.markDone(task) } label: { Label("완료", systemImage: "checkmark.circle") }
            Menu {
                ForEach(MatrixQuadrant.assignable) { q in
                    Button { model.assign(task, to: q) } label: { Label("\(q.title) · \(q.actionLabel)", systemImage: q.symbol) }
                }
            } label: { Label("매트릭스로 이동", systemImage: "square.grid.2x2") }
            Button { organizeTask = task } label: { Label("일정·정리", systemImage: "calendar") }
            Button { model.convertToRoutine(task) } label: { Label("루틴으로 만들기", systemImage: "repeat") }
            if FocusSessionManager.shared.isSupported {
                Button { FocusSessionManager.shared.start(task: task, in: model) } label: { Label("집중 시작", systemImage: "timer") }
            }
            Button(role: .destructive) { model.archive(task) } label: { Label("보관", systemImage: "archivebox") }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(showArchive ? "보관함이 비어 있어요" : "받은함이 깨끗해요", systemImage: showArchive ? "archivebox" : "tray")
        } description: {
            Text(showArchive ? "정리한 항목이 여기에 모여요."
                             : "앱을 열지 않아도 Siri·단축어·위젯·액션 버튼으로 할 일을 남길 수 있어요. 남긴 할 일은 모두 여기로 모입니다.")
        }
        .padding(.top, Theme.Spacing.xl)
    }
}
