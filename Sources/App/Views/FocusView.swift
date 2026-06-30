import SwiftUI

/// 집중 — pick a "지금 하기" task and start a Live Matrix focus session.
struct FocusView: View {
    @Environment(TaskModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var focus = FocusSessionManager.shared

    private var candidates: [MatrixTask] {
        let urgent = model.tasks(in: .urgentImportant)
        return urgent.isEmpty ? model.tasks(in: .importantNotUrgent) : urgent
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    if focus.isRunning {
                        runningCard
                    }
                    if !focus.isSupported {
                        Text("이 기기에서는 라이브 액티비티를 사용할 수 없어요. 설정에서 라이브 액티비티를 켜 주세요.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                    }
                    candidatesSection
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.s)
            }
            .background(Theme.screenBackground)
            .navigationTitle("지금 집중")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
    }

    private var runningCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("집중 중", systemImage: "timer").font(.subheadline.weight(.semibold))
                .foregroundStyle(MatrixQuadrant.urgentImportant.accent)
            Text(focus.activeTaskTitle ?? "집중 세션").font(.title3.weight(.semibold))
            Button(role: .destructive) { focus.stop() } label: {
                Label("집중 종료", systemImage: "stop.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("지금 할 일").font(.headline)
            if candidates.isEmpty {
                Text("지금 집중할 일이 없어요. 받은함을 정리해 매트릭스에 추가해 보세요.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(candidates) { task in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title).font(.subheadline)
                            Text(task.quadrant.actionLabel).font(.caption2).foregroundStyle(task.quadrant.accent)
                        }
                        Spacer()
                        Button {
                            focus.start(task: task, in: model)
                        } label: { Label("집중", systemImage: "play.fill").font(.caption.weight(.semibold)) }
                            .buttonStyle(.borderedProminent)
                            .disabled(!focus.isSupported)
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
