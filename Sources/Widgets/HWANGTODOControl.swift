import WidgetKit
import SwiftUI
import AppIntents

/// Control Center control (iOS 18+). A third-party control can TRIGGER/open the
/// app — it cannot be a full editor — so this opens HWANGTODO capture. Guarded so
/// the iOS 17 build is unaffected.
@available(iOS 18.0, *)
struct HWANGTODOControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.hwangtodo.control.capture") {
            ControlWidgetButton(action: OpenCaptureControlIntent()) {
                Label("빠른 기록", systemImage: "plus.circle")
            }
        }
        .displayName("HWANGTODO 빠른 기록")
        .description("HWANGTODO 빠른 기록을 엽니다.")
    }
}

@available(iOS 18.0, *)
struct OpenCaptureControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Open HWANGTODO Capture"
    static var openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult { .result() }
}
