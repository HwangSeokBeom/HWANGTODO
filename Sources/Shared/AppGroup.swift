import Foundation

/// Shared constants used across the app, the widget extension, and AppIntents.
/// The App Group is what lets all three system surfaces read/write the SAME
/// store — no split-brain between widget data, intent data, and app data.
enum AppGroup {
    /// Must match the App Group entitlement on both the app and widget targets.
    static let identifier = "group.com.hwangtodo.shared"

    /// Custom URL scheme used by widgets and notifications to deep-link in.
    static let urlScheme = "hwangtodo"
}

/// Centralised deep links. Widgets, notifications, and Control Center use these.
enum DeepLink {
    static let matrix = URL(string: "\(AppGroup.urlScheme)://matrix")!
    static let inbox = URL(string: "\(AppGroup.urlScheme)://inbox")!
    static let capture = URL(string: "\(AppGroup.urlScheme)://capture")!
    static let chat = URL(string: "\(AppGroup.urlScheme)://chat")!
    static let calendar = URL(string: "\(AppGroup.urlScheme)://calendar")!
    static let setup = URL(string: "\(AppGroup.urlScheme)://setup")!
    static let focus = URL(string: "\(AppGroup.urlScheme)://focus")!
    static let routine = URL(string: "\(AppGroup.urlScheme)://routine")!

    static func quadrant(_ quadrant: MatrixQuadrant) -> URL {
        URL(string: "\(AppGroup.urlScheme)://quadrant/\(quadrant.rawValue)")!
    }
}
