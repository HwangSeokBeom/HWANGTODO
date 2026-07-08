import Foundation

/// Shared constants used across the app, the widget extension, and AppIntents.
/// The App Group is what lets every system surface read/write the SAME store —
/// no split-brain between widget data, intent data, and app data.
public nonisolated enum AppGroup {
    /// Must match the App Group entitlement on both the app and widget targets.
    public static let identifier = "group.com.hwangtodo.shared"

    /// Custom URL scheme used by widgets, notifications, and controls to deep-link in.
    public static let urlScheme = "hwangtodo"

    /// UserDefaults shared across the app and the widget extension.
    /// Falls back to `.standard` only in misconfigured builds (see `SharedStore`).
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Stable WidgetKit kind strings. Changing one removes the widget from users'
/// Home/Lock Screens, so these are frozen — never rename.
public nonisolated enum WidgetKind {
    public static let homeSmall = "HWANGTODOHomeSmall"
    public static let homeMedium = "HWANGTODOHomeMedium"
    public static let homeLarge = "HWANGTODOHomeLarge"
    public static let lockCircular = "HWANGTODOLockCircular"
    public static let lockRectangular = "HWANGTODOLockRectangular"
    public static let lockInline = "HWANGTODOLockInline"
    public static let captureControl = "com.hwangtodo.control.capture"
}
