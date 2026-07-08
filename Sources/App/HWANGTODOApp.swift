import HWANGTODOCore
import SwiftData
import SwiftUI

@main
struct HWANGTODOApp: App {
    @State private var repository: TodoRepository
    @State private var router = AppRouter()
    @State private var surfaceStatus = SurfaceStatusService()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Order matters: import the pre-1.0 JSON store before the first fetch,
        // and install the notification delegate before launch finishes so
        // cold-start notification action taps are never dropped.
        LegacyJSONImporter.importIfNeeded(into: SharedStore.context)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(DebugSeeder.launchArgument) {
            DebugSeeder.seed()
        }
        #endif
        let repository = TodoRepository()
        let router = AppRouter()
        AppRouter.current = router
        CaptureRepository.live = repository
        NotificationManager.shared.bootstrap(repository: repository, router: router)
        #if DEBUG
        // Simulator QA: `-hwangtodo-route <deep-link-host>` jumps straight to a
        // screen, because `simctl openurl` is gated behind a confirm dialog.
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-hwangtodo-route"),
           arguments.indices.contains(flag + 1),
           let url = URL(string: "\(AppGroup.urlScheme)://\(arguments[flag + 1])") {
            router.handle(url: url)
        }
        // UI tests: deterministic clean slate — empty store, onboarding done.
        if arguments.contains("-hwangtodo-uitest-reset") {
            DebugSeeder.wipeAll()
            repository.reload()
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        #endif
        _repository = State(initialValue: repository)
        _router = State(initialValue: router)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()

                if !hasCompletedOnboarding {
                    OnboardingView { hasCompletedOnboarding = true }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environment(repository)
            .environment(router)
            .environment(surfaceStatus)
            .modelContainer(SharedStore.container)
            .animation(.easeInOut, value: hasCompletedOnboarding)
            .onOpenURL { url in
                repository.reload()
                // A deep link is an explicit "use the app now" — never let it
                // die behind the onboarding overlay (spec §6.6).
                hasCompletedOnboarding = true
                router.handle(url: url)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                repository.reload()
                FocusSessionManager.shared.attach(repository: repository)
                // Widget-process completions can't touch our pending
                // notifications — reconcile them on every foreground.
                NotificationManager.shared.pruneStaleTaskReminders()
                Task { await surfaceStatus.refresh() }
            }
        }
    }
}
