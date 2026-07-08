import ActivityKit
import AppIntents
import Foundation
import HWANGTODOCore
import HWANGTODODesign
import OSLog
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Live Matrix (spec §7)

/// The Live Activity showing the task currently in focus on the lock screen
/// and in the Dynamic Island. Requested/updated/ended only by the app-process
/// `FocusSessionManager`; this extension renders it and hosts its buttons.
///
/// The buttons run in the widget process, which cannot repaint the activity —
/// 완료 writes the completion to the shared store, 다음 leaves a marker in
/// shared defaults, and `FocusSessionManager.attach(repository:)` reconciles
/// both (advancing the queue and refreshing this activity) on app foreground.
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            FocusLockScreenCard(state: context.state)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    QuadrantTag(state.quadrant, compact: true)
                        .padding(.top, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedTimerText(startedAt: state.startedAt)
                        .padding(.top, 2)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(state.title)
                            .font(Theme.Typography.cardTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(state.progressLabel) 진행 중")
                            .font(Theme.Typography.badge.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    FocusActionButtons(state: state)
                        .padding(.top, Theme.Spacing.xs)
                }
            } compactLeading: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(state.quadrant.accent)
            } compactTrailing: {
                Text(state.progressLabel)
                    .font(Theme.Typography.badge.monospacedDigit())
                    .foregroundStyle(state.quadrant.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } minimal: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(state.quadrant.accent)
            }
            .widgetURL(DeepLink.task(state.taskID).url)
            .keylineTint(state.quadrant.accent)
        }
    }
}

// MARK: - 잠금화면 카드

/// Lock-screen presentation: quadrant accent bar, current task, elapsed time,
/// n/m progress, the next task, and the 완료/다음 buttons (spec §7).
private struct FocusLockScreenCard: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Capsule()
                .fill(state.quadrant.accent)
                .frame(width: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.xs) {
                    QuadrantTag(state.quadrant, compact: true)
                    Spacer(minLength: 0)
                    ElapsedTimerText(startedAt: state.startedAt)
                }
                Text(state.title)
                    .font(Theme.Typography.cardTitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView(value: Double(state.doneCount), total: Double(max(state.totalCount, 1)))
                        .tint(state.quadrant.accent)
                    Text(state.progressLabel)
                        .font(Theme.Typography.meta.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement()
                .accessibilityLabel("진행 \(state.progressLabel)")
                if let next = state.nextTitle {
                    Text("다음: \(next)")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                FocusActionButtons(state: state)
            }
        }
        .padding(Theme.Spacing.m)
        .widgetURL(DeepLink.task(state.taskID).url)
    }
}

/// 완료 + 다음, shared by the lock screen card and the expanded island.
/// 다음 only appears when a next task exists — skipping past the last task
/// would just end the session, which belongs to the in-app 종료 button.
private struct FocusActionButtons: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button(intent: FocusCompleteIntent(id: state.taskID)) {
                Label("완료", systemImage: "checkmark")
                    .font(Theme.Typography.meta)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(state.quadrant.accent)
            .invalidatableContent()
            .accessibilityLabel("\(state.title) 완료")

            if state.nextTitle != nil {
                Button(intent: FocusSkipIntent(id: state.taskID)) {
                    Label("다음", systemImage: "arrow.right")
                        .font(Theme.Typography.meta)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .invalidatableContent()
                .accessibilityLabel("다음 할 일로 넘어가기")
            }
        }
    }
}

/// Elapsed session time, ticked by the system clock (no timeline churn).
/// Width-capped so the auto-expanding timer text never pushes layout around.
private struct ElapsedTimerText: View {
    let startedAt: Date

    var body: some View {
        // 24h upper bound: a focus session never legitimately outlives it.
        Text(timerInterval: startedAt ... startedAt.addingTimeInterval(86_400), countsDown: false)
            .font(Theme.Typography.meta.monospacedDigit())
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 64)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityLabel("경과 시간")
    }
}

// MARK: - 위젯 프로세스 인텐트

/// Shared-defaults key `FocusSessionManager.applyPendingSkip()` reads.
/// Must match `Sources/App/Services/FocusSessionManager.swift`.
private let pendingSkipKey = "focus.pendingSkipTaskID"

/// 완료 button. Runs in the widget process: marks the task done through
/// `SharedStore.context` (the same write the app would make) and reloads
/// widget timelines. The activity itself stays as-is until the app foregrounds
/// and `attach(repository:)` advances the queue — only the app can repaint it.
struct FocusCompleteIntent: AppIntent {
    static let title: LocalizedStringResource = "집중 중인 할 일 완료"
    static let description = IntentDescription("잠금화면에서 집중 중인 할 일을 완료 처리합니다.")
    /// Activity-internal affordance — a raw UUID parameter is useless in the
    /// 단축어 app, so keep it out of the gallery.
    static let isDiscoverable = false

    static let log = Logger(subsystem: "com.hwangtodo.app", category: "FocusCompleteIntent")

    @Parameter(title: "할 일 ID")
    var id: String

    init() {}

    init(id: UUID) {
        self.id = id.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: id) else {
            Self.log.error("malformed task id: \(id, privacy: .public)")
            return .result()
        }
        var descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        let context = SharedStore.context
        if let item = try? context.fetch(descriptor).first, item.isOpen {
            item.status = .done
            item.completedAt = item.completedAt ?? .now
            item.updatedAt = .now
            do {
                try context.save()
            } catch {
                Self.log.error("save failed: \(error, privacy: .public)")
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 다음 button. The session queue is in-memory in the app process, so this
/// only records which task the user skipped; `FocusSessionManager` applies it
/// (and refreshes the activity) on the next foreground. Stale markers — the
/// current task changed in between — are dropped by the manager's ID check.
struct FocusSkipIntent: AppIntent {
    static let title: LocalizedStringResource = "다음 할 일로 넘어가기"
    static let description = IntentDescription("잠금화면에서 집중 중인 할 일을 건너뛰고 다음 할 일로 넘어갑니다.")
    static let isDiscoverable = false

    @Parameter(title: "할 일 ID")
    var id: String

    init() {}

    init(id: UUID) {
        self.id = id.uuidString
    }

    func perform() async throws -> some IntentResult {
        AppGroup.defaults.set(id, forKey: pendingSkipKey)
        return .result()
    }
}

// MARK: - Previews

private extension FocusActivityAttributes.ContentState {
    static var sample: FocusActivityAttributes.ContentState {
        FocusActivityAttributes.ContentState(
            taskID: UUID(),
            title: "회의 자료 마무리해서 팀에 공유",
            quadrantRaw: Quadrant.urgentImportant.rawValue,
            startedAt: .now.addingTimeInterval(-184),
            doneCount: 1,
            totalCount: 4,
            nextTitle: "은행 서류 제출"
        )
    }

    static var lastTask: FocusActivityAttributes.ContentState {
        FocusActivityAttributes.ContentState(
            taskID: UUID(),
            title: "발표 리허설",
            quadrantRaw: Quadrant.urgentImportant.rawValue,
            startedAt: .now.addingTimeInterval(-1_260),
            doneCount: 3,
            totalCount: 4,
            nextTitle: nil
        )
    }
}

#Preview("잠금화면", as: .content, using: FocusActivityAttributes()) {
    FocusLiveActivity()
} contentStates: {
    FocusActivityAttributes.ContentState.sample
    FocusActivityAttributes.ContentState.lastTask
}

#Preview("확장", as: .dynamicIsland(.expanded), using: FocusActivityAttributes()) {
    FocusLiveActivity()
} contentStates: {
    FocusActivityAttributes.ContentState.sample
}

#Preview("컴팩트", as: .dynamicIsland(.compact), using: FocusActivityAttributes()) {
    FocusLiveActivity()
} contentStates: {
    FocusActivityAttributes.ContentState.sample
}

#Preview("미니멀", as: .dynamicIsland(.minimal), using: FocusActivityAttributes()) {
    FocusLiveActivity()
} contentStates: {
    FocusActivityAttributes.ContentState.sample
}
