import AppIntents
import HWANGTODOCore
import SwiftUI
import WidgetKit

// MARK: - 제어센터 컨트롤

/// 빠른 기록 control (spec §6.5, §6.2): one tap from 제어센터, the lock
/// screen's control slot, or the 액션 버튼 opens quick capture with the
/// keyboard up.
///
/// iOS does not allow a full text editor inside a control (spec §6.5), so the
/// honest design is a launcher: the button deep-links straight into the
/// capture sheet instead of pretending to record in place.
struct CaptureControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: WidgetKind.captureControl) {
            ControlWidgetButton(action: OpenCaptureControlIntent()) {
                Label("빠른 기록", systemImage: "bolt.fill")
            }
        }
        .displayName("빠른 기록")
        .description("탭 한 번으로 빠른 기록 입력 화면을 바로 열어요. 제어센터·잠금화면·액션 버튼에 추가할 수 있어요.")
    }
}

// MARK: - 컨트롤 인텐트

/// Runs in the widget-extension process, which cannot navigate the app
/// directly — it opens the capture deep link and `AppRouter` takes it from
/// there (sheet up, keyboard focused).
struct OpenCaptureControlIntent: AppIntent {
    static let title: LocalizedStringResource = "빠른 기록 열기"
    static let description = IntentDescription("빠른 기록 입력 화면을 바로 엽니다.")
    /// Opening the app is the entire behavior of this control.
    static let openAppWhenRun = true
    /// Control-internal affordance — the app-process `OpenQuickCaptureIntent`
    /// is the one exposed in the 단축어 gallery, so keep this out of it.
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(DeepLink.capture(source: .controlCenter).url))
    }
}
