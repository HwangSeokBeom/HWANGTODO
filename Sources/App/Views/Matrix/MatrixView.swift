import SwiftUI

/// 매트릭스 — the organization layer (not the capture center). Review what you
/// captured and decide where it belongs. Minimal 2×2, short Korean labels.
struct MatrixView: View {
    @Environment(TaskModel.self) private var model
    @Environment(AppRouter.self) private var router

    @State private var organizeTask: MatrixTask?

    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.m),
                           GridItem(.flexible(), spacing: Theme.Spacing.m)]

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    if !model.inbox.isEmpty { unsortedStrip }
                    matrixGrid
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.s)
            }
            .background(Theme.screenBackground)
            .navigationTitle("매트릭스")
            .tabBarSafeBottomPadding()
            .navigationDestination(item: $router.focusedQuadrant) { QuadrantDetailView(quadrant: $0) }
            .sheet(item: $organizeTask) { OrganizeSheet(task: $0) }
        }
    }

    private var unsortedStrip: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Label("정리 전", systemImage: "circle.dotted").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(model.inbox.count)").foregroundStyle(.secondary)
                Button { router.selectedTab = .inbox } label: { Text("모두 정리").font(.subheadline) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(model.inbox.prefix(8)) { task in
                        Button { organizeTask = task } label: {
                            Text(task.title)
                                .font(.subheadline).lineLimit(1)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .cardSurface()
    }

    private var matrixGrid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
            ForEach(MatrixQuadrant.assignable) { q in
                Button { router.focusedQuadrant = q } label: {
                    QuadrantCard(quadrant: q, count: model.count(in: q),
                                 topTasks: Array(model.tasks(in: q).prefix(3)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
