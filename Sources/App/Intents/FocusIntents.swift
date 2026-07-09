import AppIntents
import Foundation
import HWANGTODOCore

// 집중 세션을 움직이는 인텐트들 — 앱 프로세스에서 실행.
//
// `LiveActivityIntent` conformance makes the system run `perform()` in the
// app's process, where `FocusSessionManager`'s in-memory queue lives — the
// only place the session can actually advance.
//
// Note: the Live Activity's on-screen buttons do NOT reference these types.
// The widget extension cannot see app-target code, so its buttons use the
// widget-process intents in `Sources/Widgets/FocusLiveActivity.swift`
// (store write + shared-defaults 다음 marker) and the app reconciles via
// `FocusSessionManager.attach(repository:)` on foreground. These intents
// exist for 단축어 automation ("집중 완료" 등) while a session is running.

// MARK: - 완료

nonisolated struct CompleteFocusedTaskIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "집중 중인 할 일 완료"
    static let description = IntentDescription(
        "진행 중인 집중에서 지금 할 일을 완료 처리하고 다음 할 일로 넘어갑니다. 집중이 진행 중일 때만 동작해요.",
        categoryName: "집중"
    )

    @MainActor
    func perform() async throws -> some IntentResult {
        // No-op when no session is active (or the app process was relaunched
        // and the in-memory queue is gone) — never guesses at a task to complete.
        FocusSessionManager.shared.completeCurrent()
        return .result()
    }
}

// MARK: - 다음

nonisolated struct AdvanceFocusTaskIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "다음 할 일로 넘어가기"
    static let description = IntentDescription(
        "진행 중인 집중에서 지금 할 일을 건너뛰고 다음 할 일로 넘어갑니다. 건너뛴 일은 완료되지 않고 제자리에 남아요.",
        categoryName: "집중"
    )

    @MainActor
    func perform() async throws -> some IntentResult {
        FocusSessionManager.shared.advance()
        return .result()
    }
}
