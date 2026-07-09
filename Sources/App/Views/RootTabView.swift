import HWANGTODOCore
import HWANGTODODesign
import SwiftData
import SwiftUI

/// The app shell (spec §4): 기록·정리·일정·루틴·설정 tabs plus the always-available
/// quick-capture accessory above the tab bar — capture must never be more than
/// one tap away, on any tab (spec §2).
///
/// Sheet presentation is router-driven so deep links from widgets, notifications,
/// and the Live Activity land here regardless of which tab is visible.
struct RootTabView: View {
    @Environment(TodoRepository.self) private var repository
    @Environment(AppRouter.self) private var router

    /// Draft in the quick-capture accessory; cleared by the field on submit.
    @State private var quickCaptureText = ""
    /// Bumped once per saved capture — drives the success haptic.
    @State private var captureCount = 0

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab(Terminology.tabCapture, systemImage: "bolt.fill", value: AppRouter.Tab.capture) {
                CaptureHomeView()
            }
            Tab(Terminology.tabOrganize, systemImage: "square.grid.2x2", value: AppRouter.Tab.organize) {
                MatrixView()
            }
            Tab(Terminology.tabSchedule, systemImage: "calendar", value: AppRouter.Tab.schedule) {
                ScheduleView()
            }
            Tab(Terminology.tabRoutine, systemImage: "repeat", value: AppRouter.Tab.routine) {
                RoutineListView()
            }
            Tab(Terminology.tabSettings, systemImage: "gearshape", value: AppRouter.Tab.settings) {
                SettingsChecklistView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            QuickCaptureField(text: $quickCaptureText) { value in
                guard repository.capture(value, source: .app) != nil else { return }
                captureCount += 1
            }
        }
        .sensoryFeedback(.success, trigger: captureCount)
        .sheet(
            item: $router.presentedSheet,
            onDismiss: { router.pendingCaptureSource = nil },
            content: { sheet in
                switch sheet {
                case .capture: CaptureSheetView()
                case .chat: ChatView()
                case .focus: FocusView()
                }
            }
        )
        .sheet(item: presentedTask) { task in
            TaskDetailView(taskID: task.id)
        }
    }

    /// `router.presentedTaskID` bridged to `sheet(item:)`; dismissing the sheet
    /// writes nil back so a repeated deep link to the same task presents again.
    private var presentedTask: Binding<PresentedTask?> {
        Binding(
            get: { router.presentedTaskID.map { PresentedTask(id: $0) } },
            set: { router.presentedTaskID = $0?.id }
        )
    }
}

/// Identifiable wrapper so a bare task UUID can drive `sheet(item:)`.
private struct PresentedTask: Identifiable {
    let id: UUID
}

#Preview {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: SharedStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )
    RootTabView()
        .environment(TodoRepository(context: ModelContext(container)))
        .environment(AppRouter())
        .environment(SurfaceStatusService())
        .modelContainer(container)
}
