import AppIntents

/// Siri·단축어에 노출되는 문구 (spec §6.3).
///
/// iOS policy: every phrase MUST contain `\(.applicationName)` — the spec's
/// bare "할 일 추가"/"오늘 할 일 추가" cannot be registered as-is (iOS
/// Limited); the closest speakable forms below carry the app name.
/// `SurfaceDetailSheet` shows these to users — keep the two lists in sync.
nonisolated struct HWANGTODOShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SiriAddTaskIntent(),
            phrases: [
                "\(.applicationName)에 추가",
                "\(.applicationName) 할 일 추가",
                "\(.applicationName) 빠른 기록",
                "\(.applicationName) 빠른 기록 추가",
                "\(.applicationName)에 나중에 정리할 일 추가",
            ],
            shortTitle: "빠른 기록",
            systemImageName: "bolt.fill"
        )
        AppShortcut(
            intent: OpenQuickCaptureIntent(),
            phrases: [
                "\(.applicationName) 열어 줘",
            ],
            shortTitle: "빠른 기록 열기",
            systemImageName: "arrow.up.forward.app"
        )
    }
}
