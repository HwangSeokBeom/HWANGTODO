import HWANGTODOCore
import SwiftUI

/// The nine 설정 checklist entries (spec §13). Display order is fixed; the
/// capture/glance split mirrors how users meet each surface — 기록 통로 first.
enum SettingsSurface: String, CaseIterable, Identifiable {
    case lockWidget
    case homeWidget
    case actionButton
    case siriShortcuts
    case controlCenter
    case notifications
    case calendar
    case liveMatrix
    case noteLink

    var id: String { rawValue }

    /// 앱을 열지 않고 기록하는 통로들.
    static let captureGroup: [SettingsSurface] = [
        .lockWidget, .homeWidget, .actionButton, .siriShortcuts, .controlCenter,
    ]

    /// 확인·연결 기능들.
    static let glanceGroup: [SettingsSurface] = [
        .notifications, .calendar, .liveMatrix, .noteLink,
    ]

    var name: String {
        switch self {
        case .lockWidget: "잠금화면 위젯"
        case .homeWidget: "홈 화면 위젯"
        case .actionButton: "액션 버튼"
        case .siriShortcuts: "Siri·단축어"
        case .controlCenter: "제어센터"
        case .notifications: "알림"
        case .calendar: "캘린더"
        case .liveMatrix: "Live Matrix"
        case .noteLink: Terminology.linkNote
        }
    }

    var symbol: String {
        switch self {
        case .lockWidget: "lock.iphone"
        case .homeWidget: "rectangle.3.group"
        case .actionButton: "button.horizontal.top.press"
        case .siriShortcuts: "mic.fill"
        case .controlCenter: "switch.2"
        case .notifications: "bell.badge.fill"
        case .calendar: "calendar"
        case .liveMatrix: "dot.radiowaves.left.and.right"
        case .noteLink: "note.text"
        }
    }

    /// One-line row description — what the surface does *for the user*.
    var blurb: String {
        switch self {
        case .lockWidget: "잠금화면에서 오늘 할 일과 다음 할 일을 바로 확인해요"
        case .homeWidget: "홈 화면에서 요약을 보고 한 번에 기록으로 들어가요"
        case .actionButton: "버튼 한 번으로 앱을 열지 않고 기록해요"
        case .siriShortcuts: "말 한마디로 할 일을 남겨요"
        case .controlCenter: "제어센터에서 바로 빠른 기록을 열어요"
        case .notifications: "할 일·루틴·하루 점검 알림을 받아요"
        case .calendar: "할 일을 캘린더 일정으로 만들어 계획해요"
        case .liveMatrix: "잠금화면과 Dynamic Island에서 지금 집중할 일을 봐요"
        case .noteLink: "할 일에 메모나 Apple 메모 링크를 연결해요"
        }
    }

    /// Live availability from the shared prober (spec §13: "지금 이 기능을
    /// 사용할 수 있는지"). 메모 연결 is app-internal, so it is always usable.
    func state(in service: SurfaceStatusService) -> SurfaceState {
        switch self {
        case .lockWidget: service.lockWidgetState
        case .homeWidget: service.homeWidgetState
        case .actionButton: service.actionButtonState
        case .siriShortcuts: service.siriState
        case .controlCenter: service.controlCenterState
        case .notifications: service.notificationState
        case .calendar: service.calendarState
        case .liveMatrix: service.liveActivityState
        case .noteLink: .available
        }
    }
}
