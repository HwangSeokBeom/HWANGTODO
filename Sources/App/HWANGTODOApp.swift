import SwiftUI

@main
struct HWANGTODOApp: App {
    @State private var model = TaskModel()
    @State private var router = AppRouter()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    init() { SampleDataSeeder.seedIfNeeded() }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                    .environment(model)
                    .environment(router)

                if !hasCompletedOnboarding {
                    OnboardingView { hasCompletedOnboarding = true }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut, value: hasCompletedOnboarding)
            .onAppear {
                NotificationManager.shared.router = router
                NotificationManager.shared.model = model
            }
            .onOpenURL { url in
                model.reload()
                router.handle(url: url)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    model.reload()
                    CalendarService.shared.refreshStatus()
                    FocusSessionManager.shared.refresh()
                }
            }
        }
    }
}
