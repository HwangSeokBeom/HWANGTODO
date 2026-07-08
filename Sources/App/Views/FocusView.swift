import HWANGTODOCore
import HWANGTODODesign
import SwiftData
import SwiftUI
import UIKit

/// 집중 sheet (spec §7) — the in-app face of one focus session, mirroring the
/// Live Matrix on the lock screen: current task hero, elapsed time, n/m
/// progress, 완료·다음·종료.
///
/// The session itself lives in `FocusSessionManager`; this view only renders
/// its state and forwards taps. When no session is running, the sheet offers
/// to start one over `repository.focusQueue` (지금 할 일) — so the 집중 deep
/// link and the 정리 toolbar button both land somewhere useful.
struct FocusView: View {
    @Environment(TodoRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Shared session driver — @Observable, so reads in `body` are tracked.
    private var manager: FocusSessionManager { .shared }

    /// Bumped per 완료 in this presentation — haptic + 모두 완료 state.
    @State private var completionTick = 0

    var body: some View {
        NavigationStack {
            Group {
                if manager.isActive, let task = manager.currentTask {
                    activeSession(task)
                } else if !repository.focusQueue.isEmpty {
                    readyToStart
                } else if completionTick > 0 {
                    EmptyStateView(
                        symbol: "checkmark.seal.fill",
                        title: "모두 완료했어요",
                        message: "이번 집중에서 계획한 일을 전부 끝냈어요"
                    )
                } else {
                    EmptyStateView(
                        symbol: "bolt.slash",
                        title: "집중할 일이 없어요",
                        message: "정리 탭에서 할 일을 '지금 할 일'로 옮기면 집중을 시작할 수 있어요"
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.screenBackground)
            .navigationTitle("집중")
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
            // Re-sync with the store (완료 from the Live Activity, 다음 marker
            // from the lock screen) every time the sheet appears.
            .task { manager.attach(repository: repository) }
            .sensoryFeedback(.success, trigger: completionTick)
        }
    }

    // MARK: - Active session (spec §7)

    private func activeSession(_ task: TodoItem) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer(minLength: 0)

            ZStack {
                ProgressRing(progress: manager.progress, lineWidth: 8, tint: task.quadrant.accent)
                VStack(spacing: 2) {
                    Text(manager.progressLabel)
                        .font(Theme.Typography.number)
                    Text("진행")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 132, height: 132)
            .accessibilityElement()
            .accessibilityLabel("진행 \(manager.progressLabel)")

            VStack(spacing: Theme.Spacing.s) {
                QuadrantTag(task.quadrant)
                Text(task.title)
                    .font(Theme.Typography.sectionTitle)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                // Elapsed time, rendered by the system clock — no timers here.
                // 24h upper bound: a focus session never legitimately outlives it.
                Text(
                    timerInterval: manager.startedAt ... manager.startedAt.addingTimeInterval(86_400),
                    countsDown: false
                )
                .font(Font.largeTitle.weight(.semibold).monospacedDigit())
                .accessibilityLabel("경과 시간")
                Text("경과 시간")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
            }

            if let next = manager.nextTask {
                Text("다음: \(next.title)")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)

            if !manager.activitiesEnabled {
                activityNotice
            }

            VStack(spacing: Theme.Spacing.s) {
                Button {
                    manager.completeCurrent()
                    completionTick += 1
                } label: {
                    Label("완료", systemImage: "checkmark.circle.fill")
                        .font(Theme.Typography.cardTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(task.quadrant.accent)

                HStack(spacing: Theme.Spacing.s) {
                    Button {
                        manager.advance()
                    } label: {
                        Label("다음", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    // 다음 with nothing after would silently end the session —
                    // disable it instead of surprising the user.
                    .disabled(manager.nextTask == nil)

                    Button(role: .destructive) {
                        manager.end()
                        dismiss()
                    } label: {
                        Label("종료", systemImage: "stop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(Theme.Spacing.l)
    }

    // MARK: - Ready to start

    private var readyToStart: some View {
        let queue = repository.focusQueue
        return VStack(spacing: Theme.Spacing.l) {
            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.s) {
                Image(systemName: "bolt.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Quadrant.urgentImportant.accent)
                    .accessibilityHidden(true)
                Text("\(Quadrant.urgentImportant.title) \(queue.count)개")
                    .font(Theme.Typography.sectionTitle)
                Text("한 번에 하나씩, 완료하면 다음으로 넘어가요")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach(queue.prefix(3)) { item in
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: "circle")
                            .font(Theme.Typography.badge)
                            .foregroundStyle(item.quadrant.accent)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(Theme.Typography.cardTitle)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                if queue.count > 3 {
                    Text("외 \(queue.count - 3)개")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()

            Spacer(minLength: 0)

            if !manager.activitiesEnabled {
                activityNotice
            }

            Button {
                manager.start(queue: queue)
            } label: {
                Label(Terminology.startFocus, systemImage: "play.fill")
                    .font(Theme.Typography.cardTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.hwangAccent)
        }
        .padding(Theme.Spacing.l)
    }

    // MARK: - Live Activity 안내 (honest: iOS setting can turn it off)

    private var activityNotice: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("잠금화면 실시간 현황이 꺼져 있어요")
                    .font(Theme.Typography.cardTitle)
                Text("설정에서 실시간 현황을 허용하면 잠금화면과 Dynamic Island에서도 집중 상태를 볼 수 있어요.")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("설정 열기", action: openAppSettings)
                .font(Theme.Typography.meta)
        }
        .cardSurface()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#if DEBUG
#Preview("집중 시작 전") {
    let container = FocusPreviewData.container(urgentCount: 4)
    FocusView()
        .environment(TodoRepository(context: container.mainContext))
        .environment(AppRouter())
        .modelContainer(container)
}

#Preview("집중할 일 없음") {
    let container = FocusPreviewData.container(urgentCount: 0)
    FocusView()
        .environment(TodoRepository(context: container.mainContext))
        .environment(AppRouter())
        .modelContainer(container)
}

private enum FocusPreviewData {
    static func container(urgentCount: Int) -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: SharedStore.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let titles = ["회의 자료 마무리", "세금 신고 준비", "은행 서류 제출", "발표 리허설"]
        for title in titles.prefix(urgentCount) {
            context.insert(TodoItem(title: title, status: .active, quadrant: .urgentImportant, source: .app))
        }
        try? context.save()
        return container
    }
}
#endif
