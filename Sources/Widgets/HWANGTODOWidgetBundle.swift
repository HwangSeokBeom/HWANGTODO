import WidgetKit
import SwiftUI

/// The widget extension entry point: Home Screen matrix widgets, Lock Screen
/// accessory widgets, the iOS 18 Control Center control, and the Live Activity.
@main
struct HWANGTODOWidgetBundle: WidgetBundle {
    var body: some Widget {
        HomeMatrixSmall()
        HomeMatrixMedium()
        HomeMatrixLarge()
        LockMatrixCircular()
        LockMatrixRectangular()
        if #available(iOS 18.0, *) {
            HWANGTODOControl()
        }
        if #available(iOS 16.1, *) {
            FocusLiveActivity()
        }
    }
}
