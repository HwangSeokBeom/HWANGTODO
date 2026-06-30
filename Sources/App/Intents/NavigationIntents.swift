import AppIntents

/// Opens 매트릭스 (the app's organization layer).
struct OpenMatrixIntent: AppIntent {
    static var title: LocalizedStringResource = "내 매트릭스 열기"
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult { .result() }
}

/// Opens the in-app fallback 빠른 기록 sheet.
struct OpenCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "HWANGTODO 빠른 기록 열기"
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult { .result() }
}

/// Starts a 라이브 매트릭스 focus session on the top "지금 하기" task, then opens the app.
struct StartMatrixFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "집중 시작"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let top = TaskStore.shared.topTasks(in: .urgentImportant, limit: 1).first
            ?? TaskStore.shared.topTasks(in: .importantNotUrgent, limit: 1).first
        guard let task = top else { return .result(dialog: "집중할 할 일이 없어요.") }
        FocusSessionManager.shared.start(task: task, in: TaskModel())
        return .result(dialog: "\(task.title)에 집중을 시작해요.")
    }
}

/// Korean phrases + discoverable shortcuts. Lives in the app target so iOS
/// surfaces these in 단축어/Siri and they can be bound to the 액션 버튼.
struct HWANGTODOShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddHWANGTODOTaskIntent(),
            phrases: [
                "\(.applicationName)에 추가",
                "\(.applicationName)에 할 일 추가",
                "\(.applicationName) 내 매트릭스에 추가",
                "\(.applicationName)에 오늘 할 일 추가",
                "\(.applicationName)에 나중에 정리할 일 추가"
            ],
            shortTitle: "HWANGTODO에 추가",
            systemImageName: "plus.circle")
        AppShortcut(
            intent: AddChatMessageIntent(),
            phrases: ["\(.applicationName)에 빠른 메모 추가"],
            shortTitle: "빠른 메모 추가",
            systemImageName: "bubble.left")
        AppShortcut(
            intent: OpenMatrixIntent(),
            phrases: ["\(.applicationName) 내 매트릭스 열기", "\(.applicationName) 매트릭스 보기"],
            shortTitle: "매트릭스 열기",
            systemImageName: "square.grid.2x2")
        AppShortcut(
            intent: OpenCaptureIntent(),
            phrases: ["\(.applicationName) 빠른 기록"],
            shortTitle: "빠른 기록",
            systemImageName: "bolt")
        AppShortcut(
            intent: StartMatrixFocusIntent(),
            phrases: ["\(.applicationName) 집중 시작"],
            shortTitle: "집중 시작",
            systemImageName: "timer")
    }
}
