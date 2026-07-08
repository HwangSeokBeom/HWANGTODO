import HWANGTODOCore
import HWANGTODODesign
import SwiftData
import SwiftUI

/// 정리 tab (spec §8) — the organize layer, never an input screen. Quick
/// captures pile up in 정리 전; here they get sorted into the four quadrants,
/// and each quadrant leads to its own list with the spec §8 actions.
///
/// Deep links land through `router.focusedQuadrant`
/// (`hwangtodo://quadrant/…` from widgets), bound to `navigationDestination(item:)`
/// so popping the detail clears the route automatically.
struct MatrixView: View {
    @Environment(TodoRepository.self) private var repository
    @Environment(AppRouter.self) private var router

    private static let gridColumns = [
        GridItem(.flexible(), spacing: Theme.Spacing.s),
        GridItem(.flexible(), spacing: Theme.Spacing.s),
    ]

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    pendingTray
                    quadrantGrid
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.s)
            }
            .background(Theme.screenBackground)
            .navigationTitle(Terminology.tabOrganize)
            .navigationSubtitle("남긴 일을 네 분면으로 정리해요")
            .navigationDestination(item: $router.focusedQuadrant) { quadrant in
                QuadrantDetailView(quadrant: quadrant)
            }
            .toolbar {
                if !repository.focusQueue.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            router.presentedSheet = .focus
                        } label: {
                            Label(Terminology.startFocus, systemImage: "play.fill")
                        }
                        .accessibilityLabel(Terminology.startFocus)
                    }
                }
            }
        }
    }

    // MARK: - 정리 전 tray (spec §8 "정리 전 항목을 매트릭스로 이동")

    /// Where the captures wait: count + the freshest capture, one tap back to
    /// the 기록 home where 정리 전 items live.
    private var pendingTray: some View {
        let inbox = repository.inbox
        let freshest = inbox.max { $0.createdAt < $1.createdAt }
        return Button {
            router.navigate(to: .captureHome())
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.title3)
                    .foregroundStyle(Color.hwangAccent)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(Terminology.pending)
                            .font(Theme.Typography.cardTitle)
                        Text("\(inbox.count)")
                            .font(Theme.Typography.meta.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(freshest?.title ?? "모두 정리했어요")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(Theme.Typography.badge)
                    .foregroundStyle(.tertiary)
            }
            .cardSurface()
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Terminology.pending) \(inbox.count)건. 기록 화면으로 이동")
    }

    // MARK: - 2×2 quadrant grid (spec §8)

    private var quadrantGrid: some View {
        LazyVGrid(columns: Self.gridColumns, spacing: Theme.Spacing.s) {
            ForEach(Quadrant.assignable) { quadrant in
                Button {
                    router.focusedQuadrant = quadrant
                } label: {
                    QuadrantCard(
                        quadrant: quadrant,
                        openCount: repository.count(in: quadrant),
                        topTaskTitle: repository.tasks(in: quadrant).first?.title
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#if DEBUG
#Preview("정리") {
    let container = MatrixPreviewData.container(seeded: true)
    MatrixView()
        .environment(TodoRepository(context: container.mainContext))
        .environment(AppRouter())
        .modelContainer(container)
}

#Preview("빈 상태") {
    let container = MatrixPreviewData.container(seeded: false)
    MatrixView()
        .environment(TodoRepository(context: container.mainContext))
        .environment(AppRouter())
        .modelContainer(container)
}

/// In-memory store with every quadrant populated plus 정리 전 captures.
private enum MatrixPreviewData {
    static func container(seeded: Bool) -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: SharedStore.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        guard seeded else { return container }
        let context = container.mainContext
        let samples: [TodoItem] = [
            TodoItem(title: "은행 서류 제출", source: .siri),
            TodoItem(title: "장보기 목록 만들기", source: .controlCenter),
            TodoItem(title: "회의 자료 마무리", status: .active, quadrant: .urgentImportant, source: .app),
            TodoItem(title: "세금 신고 준비", status: .active, quadrant: .urgentImportant, source: .homeWidget),
            TodoItem(title: "운동 계획 세우기", status: .active, quadrant: .importantNotUrgent, source: .shortcut),
            TodoItem(title: "우편물 발송 부탁하기", status: .active, quadrant: .urgentNotImportant, source: .notification),
            TodoItem(title: "오래된 구독 정리", status: .active, quadrant: .notUrgentNotImportant, source: .app),
        ]
        samples.forEach(context.insert)
        try? context.save()
        return container
    }
}
#endif
