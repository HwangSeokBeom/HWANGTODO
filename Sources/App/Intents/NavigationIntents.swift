import AppIntents
import Foundation
import HWANGTODOCore

// 앱을 열어 특정 화면으로 이동하는 인텐트들.
//
// These run in the app process (`openAppWhenRun = true` foregrounds the app
// before `perform()`), so they navigate through `AppRouter.current` directly
// instead of a URL round-trip. `AppRouter.current` is set in `App.init`,
// which always precedes `perform()`.

// MARK: - 빠른 기록 열기

/// "HWANGTODO 열어 줘": 앱을 열고 빠른 기록 입력 시트를 바로 띄운다.
nonisolated struct OpenQuickCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "빠른 기록 열기"
    static let description = IntentDescription(
        "앱을 열고 빠른 기록 입력 화면을 바로 띄웁니다.",
        categoryName: "화면 열기"
    )
    /// Navigation is the entire behavior — the app must come to the foreground.
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.current?.navigate(to: .capture())
        return .result()
    }
}

// MARK: - 정리 열기

/// 앱을 열고 네 분면 정리 화면으로 이동한다.
nonisolated struct OpenOrganizeIntent: AppIntent {
    static let title: LocalizedStringResource = "정리 화면 열기"
    static let description = IntentDescription(
        "앱을 열고 네 분면 정리 화면으로 이동합니다.",
        categoryName: "화면 열기"
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.current?.navigate(to: .organize(quadrant: nil))
        return .result()
    }
}
