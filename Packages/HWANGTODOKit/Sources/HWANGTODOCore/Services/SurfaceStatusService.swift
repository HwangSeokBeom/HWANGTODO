import EventKit
import Foundation
import UserNotifications
import WidgetKit
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

/// One system surface's live availability, powering the 설정 checklist
/// (spec §13): not "this feature exists" but "can you use it right now".
public nonisolated enum SurfaceState: Sendable, Hashable {
    /// Verified working (permission granted / widget placed …).
    case available
    /// The user must do something first (grant permission, add widget …).
    case needsSetup
    /// iOS gives apps no way to detect this — the user has to check.
    case checkManually
    /// Permission explicitly denied; only Settings.app can fix it.
    case denied
    /// iOS policy makes this impossible; we say so honestly.
    case iosLimited

    public var label: String {
        switch self {
        case .available: "사용 가능"
        case .needsSetup: "설정 필요"
        case .checkManually: "확인 필요"
        case .denied: "권한이 꺼져 있음"
        case .iosLimited: "iOS 제한"
        }
    }

    public var symbol: String {
        switch self {
        case .available: "checkmark.circle.fill"
        case .needsSetup: "exclamationmark.circle.fill"
        case .checkManually: "questionmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .iosLimited: "info.circle.fill"
        }
    }
}

/// Live status prober for every system surface (spec §13). `refresh()` is
/// cheap and safe to call on every appearance of the 설정 tab.
@MainActor
@Observable
public final class SurfaceStatusService {
    public private(set) var notificationState: SurfaceState = .needsSetup
    public private(set) var calendarState: SurfaceState = .needsSetup
    public private(set) var homeWidgetState: SurfaceState = .checkManually
    public private(set) var lockWidgetState: SurfaceState = .checkManually
    public private(set) var liveActivityState: SurfaceState = .needsSetup
    /// Installed widget kinds+families, for showing *which* widgets are placed.
    public private(set) var installedWidgets: [String] = []

    /// Surfaces iOS never lets an app introspect — always 확인 필요.
    public let siriState: SurfaceState = .checkManually
    public let actionButtonState: SurfaceState = .checkManually
    public let controlCenterState: SurfaceState = .checkManually

    public init() {}

    public func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationState = switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .available
        case .denied: .denied
        case .notDetermined: .needsSetup
        @unknown default: .checkManually
        }

        calendarState = switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly: .available
        case .denied, .restricted: .denied
        case .notDetermined: .needsSetup
        @unknown default: .checkManually
        }

        #if canImport(ActivityKit) && os(iOS)
        liveActivityState = ActivityAuthorizationInfo().areActivitiesEnabled ? .available : .denied
        #endif

        let configurations = (try? await WidgetCenter.shared.currentConfigurations()) ?? []
        installedWidgets = configurations.map { "\($0.kind)#\(String(describing: $0.family))" }
        let lockKinds: Set<String> = [WidgetKind.lockCircular, WidgetKind.lockRectangular, WidgetKind.lockInline]
        let hasHome = configurations.contains { !lockKinds.contains($0.kind) }
        let hasLock = configurations.contains { lockKinds.contains($0.kind) }
        homeWidgetState = hasHome ? .available : .needsSetup
        lockWidgetState = hasLock ? .available : .needsSetup
    }
}
