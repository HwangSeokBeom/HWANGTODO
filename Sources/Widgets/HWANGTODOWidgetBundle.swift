import HWANGTODOCore
import SwiftUI
import WidgetKit

/// Every system surface this extension ships: home-screen widgets (spec §6.6),
/// lock-screen widgets (spec §6.1), the 제어센터 빠른 기록 control (spec §6.5),
/// and the Live Matrix Live Activity (spec §7).
///
/// Kind strings come from `WidgetKind` and are frozen — renaming one removes
/// the widget from users' Home/Lock Screens.
@main
struct HWANGTODOWidgetBundle: WidgetBundle {
    var body: some Widget {
        // 홈 화면 (spec §6.6)
        NextTaskWidget()
        MatrixOverviewWidget()
        TodayOverviewWidget()
        // 잠금화면 (spec §6.1)
        LockCircularWidget()
        LockRectangularWidget()
        LockInlineWidget()
        // 제어센터·잠금화면·액션 버튼 컨트롤 (spec §6.5)
        CaptureControlWidget()
        // Live Matrix (spec §7)
        FocusLiveActivity()
    }
}
