import Foundation

/// The single source of truth for the app's Korean vocabulary (spec §14).
///
/// Banned words — never user-facing anywhere: 받은함, 보관함, Inbox, Archive,
/// AI 분석, Dashboard, Task Manager, System Surface.
/// A unit test scans all sources for the banned list.
public nonisolated enum Terminology {
    // Tabs (spec §4)
    public static let tabCapture = "기록"
    public static let tabOrganize = "정리"
    public static let tabSchedule = "일정"
    public static let tabRoutine = "루틴"
    public static let tabSettings = "설정"

    // Capture home (spec §5)
    public static let quickCapture = "빠른 기록"
    public static let quickCaptureSubtitle = "앱을 열지 않고 남긴 할 일이 모이는 곳"
    public static let quickCapturePlaceholder = "지금 떠오른 일 빠르게 남기기"
    public static let pending = "정리 전"
    public static let completedItems = "완료한 일"
    public static let pastRecords = "지난 기록"
    public static let todayTasks = "오늘 할 일"

    // Core actions (spec §14)
    public static let doNow = "지금 하기"
    public static let scheduleIt = "일정 잡기"
    public static let makeRoutine = "루틴으로 만들기"
    public static let linkNote = "메모 연결"
    public static let startFocus = "집중 시작"
    public static let organizeLater = "나중에 정리"
    public static let organizeIntoTasks = "할 일로 정리"
    public static let captureWithoutOpening = "앱을 열지 않고 기록"

    /// The app's tagline (spec §14).
    public static let tagline = "앱을 열지 않고 기록하세요.\n떠오른 일은 빠르게 남기고, 정리는 나중에 해도 괜찮아요."
}
