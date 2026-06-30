import SwiftUI

/// Five focused tabs. The Quick Inbox (받은함) is the home — capture-first.
/// Chat and Focus are presented as sheets (reachable from anywhere via deep link).
struct RootTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            InboxView()
                .tabItem { Label("받은함", systemImage: "tray.full") }
                .tag(AppRouter.Tab.inbox)

            MatrixView()
                .tabItem { Label("매트릭스", systemImage: "square.grid.2x2") }
                .tag(AppRouter.Tab.matrix)

            CalendarView()
                .tabItem { Label("캘린더", systemImage: "calendar") }
                .tag(AppRouter.Tab.calendar)

            RoutineView()
                .tabItem { Label("루틴", systemImage: "repeat") }
                .tag(AppRouter.Tab.routine)

            SetupView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(AppRouter.Tab.setup)
        }
        .sheet(item: $router.presentedSheet) { sheet in
            switch sheet {
            case .capture: CaptureView().presentationDetents([.medium, .large])
            case .chat: ChatView()
            case .focus: FocusView()
            }
        }
    }
}
