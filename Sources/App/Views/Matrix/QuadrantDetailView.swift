import SwiftUI

/// Drill-in for a single quadrant: its tasks with quick actions and quadrant moves.
struct QuadrantDetailView: View {
    let quadrant: MatrixQuadrant

    @Environment(TaskModel.self) private var model
    @State private var organizeTask: MatrixTask?

    private var tasks: [MatrixTask] { model.tasks(in: quadrant) }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                header
                if tasks.isEmpty {
                    emptyState
                } else {
                    ForEach(tasks) { task in
                        TaskCardView(task: task, onToggleDone: { model.markDone(task) })
                            .contextMenu { quickActions(for: task) }
                            .onTapGesture { organizeTask = task }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.top, Theme.Spacing.s)
        }
        .background(Theme.screenBackground)
        .navigationTitle(quadrant.actionLabel)
        .navigationBarTitleDisplayMode(.inline)
        .tabBarSafeBottomPadding()
        .sheet(item: $organizeTask) { OrganizeSheet(task: $0) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(quadrant.title, systemImage: quadrant.symbol)
                .font(.title3.weight(.semibold)).foregroundStyle(quadrant.accent)
            Text(hint).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var hint: String {
        switch quadrant {
        case .urgentImportant: return "지금 바로 처리하세요. 급하면서 중요한 일이에요."
        case .importantNotUrgent: return "일정을 잡으세요. 진짜 성과가 나는 영역이에요."
        case .urgentNotImportant: return "맡기거나 줄이세요. 급하지만 가치는 낮아요."
        case .notUrgentNotImportant: return "줄이거나 모아서 처리하세요."
        case .unassigned: return "어디에 둘지 정해 보세요."
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("비어 있어요", systemImage: "checkmark.circle")
        } description: {
            Text("‘\(quadrant.actionLabel)’에 할 일이 없어요. 받은함에서 옮겨 보세요.")
        }
        .frame(maxWidth: .infinity).padding(.top, Theme.Spacing.xl)
    }

    @ViewBuilder
    private func quickActions(for task: MatrixTask) -> some View {
        Button { model.markDone(task) } label: { Label("완료", systemImage: "checkmark.circle") }
        if FocusSessionManager.shared.isSupported {
            Button { FocusSessionManager.shared.start(task: task, in: model) } label: { Label("집중 시작", systemImage: "timer") }
        }
        Button { organizeTask = task } label: { Label("일정·정리", systemImage: "calendar") }
        if task.noteLinkURL != nil { Button { openNote(task) } label: { Label("메모 열기", systemImage: "note.text") } }
        Menu {
            ForEach(MatrixQuadrant.assignable) { q in
                Button { model.assign(task, to: q) } label: { Label(q.title, systemImage: q.symbol) }
            }
            Button { model.assign(task, to: .unassigned) } label: { Label("받은함으로", systemImage: "tray") }
        } label: { Label("이동", systemImage: "arrow.up.arrow.down") }
        Button(role: .destructive) { model.archive(task) } label: { Label("보관", systemImage: "archivebox") }
    }

    private func openNote(_ task: MatrixTask) {
        guard let s = task.noteLinkURL, let url = URL(string: s) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}
