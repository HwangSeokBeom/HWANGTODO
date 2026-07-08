import AppIntents
import Foundation
import HWANGTODOCore

// MARK: - 분면 선택지

/// 단축어에서 고를 수 있는 분면 — `Quadrant`를 감싼 AppEnum 래퍼.
/// 패키지 타입에 AppIntents 의존성을 얹지 않기 위해 여기서 감싼다.
/// Raw values mirror `Quadrant` and are frozen: they live inside users'
/// saved shortcut configurations.
nonisolated enum QuadrantOption: String, AppEnum {
    case urgentImportant
    case importantNotUrgent
    case urgentNotImportant
    case notUrgentNotImportant

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "분면")

    static let caseDisplayRepresentations: [QuadrantOption: DisplayRepresentation] = [
        .urgentImportant: DisplayRepresentation(
            title: "지금 할 일",
            subtitle: "급하고 중요함",
            image: .init(systemName: "bolt.fill")
        ),
        .importantNotUrgent: DisplayRepresentation(
            title: "계획할 일",
            subtitle: "중요하지만 급하지 않음",
            image: .init(systemName: "calendar")
        ),
        .urgentNotImportant: DisplayRepresentation(
            title: "맡길 일",
            subtitle: "급하지만 덜 중요함",
            image: .init(systemName: "arrow.triangle.branch")
        ),
        .notUrgentNotImportant: DisplayRepresentation(
            title: "줄일 일",
            subtitle: "급하지도 중요하지도 않음",
            image: .init(systemName: "arrow.down.right.circle")
        ),
    ]

    /// Explicit mapping (not a rawValue round-trip) so exhaustiveness is
    /// compiler-checked if either enum ever grows.
    var quadrant: Quadrant {
        switch self {
        case .urgentImportant: .urgentImportant
        case .importantNotUrgent: .importantNotUrgent
        case .urgentNotImportant: .urgentNotImportant
        case .notUrgentNotImportant: .notUrgentNotImportant
        }
    }
}

// MARK: - 공용 저장 경로

/// The UI's live repository, set at app startup. In-process intents write
/// through the SAME observable instance the screens render from — otherwise a
/// capture fired while the app is open (Shortcuts automation, Back Tap) would
/// not appear on screen until the next foreground reload.
@MainActor
enum CaptureRepository {
    static var live: TodoRepository?
}

/// Shared write path of the three capture intents — one repository call,
/// three honest `CaptureSource` badges (spec §5: never fake the source).
/// Returns nil for effectively-empty titles.
@MainActor
private func captureFromSystemSurface(
    title: String,
    quadrant: QuadrantOption?,
    note: String?,
    dueDate: Date?,
    source: CaptureSource
) -> TodoItem? {
    (CaptureRepository.live ?? TodoRepository()).capture(
        title,
        source: source,
        quadrant: quadrant?.quadrant ?? .unassigned,
        dueDate: dueDate,
        note: note
    )
}

/// 담긴 곳을 정직하게 알려 주는 완료 안내: 분면을 골랐으면 그 분면으로,
/// 아니면 정리 전(빠른 기록)으로 들어갔다고 말한다.
private func captureDialog(title: String, quadrant: QuadrantOption?) -> IntentDialog {
    if let quadrant {
        return IntentDialog("'\(title)' \(quadrant.quadrant.title)에 담았어요")
    }
    return IntentDialog("'\(title)' 빠른 기록에 담았어요")
}

// MARK: - 단축어 (spec §6.4)

/// Shortcuts 앱에서 실행하는 빠른 기록: 앱을 열지 않고 저장된다.
/// 제목만 필수 — 분면·메모·날짜는 선택 (캡처 먼저, 정리는 나중에).
struct AddQuickTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "할 일 빠른 기록"
    static let description = IntentDescription(
        "앱을 열지 않고 할 일을 빠른 기록에 남깁니다. 분면·메모·날짜는 골라도 되고, 비워 두면 나중에 정리하면 돼요.",
        categoryName: "빠른 기록"
    )
    /// Capture without opening the app — the product's core promise.
    static let openAppWhenRun = false

    @Parameter(title: "제목", requestValueDialog: "무엇을 기록할까요?")
    var taskTitle: String

    @Parameter(title: "분면", description: "비워 두면 정리 전에 담겨요")
    var quadrant: QuadrantOption?

    @Parameter(title: "메모")
    var note: String?

    @Parameter(title: "날짜")
    var dueDate: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$taskTitle) 빠르게 기록") {
            \.$quadrant
            \.$note
            \.$dueDate
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let item = captureFromSystemSurface(
            title: taskTitle,
            quadrant: quadrant,
            note: note,
            dueDate: dueDate,
            source: .shortcut
        ) else {
            throw $taskTitle.needsValueError("무엇을 기록할까요?")
        }
        return .result(dialog: captureDialog(title: item.title, quadrant: quadrant))
    }
}

// MARK: - Siri (spec §6.3)

/// Siri 음성으로 실행되는 빠른 기록. `AddQuickTaskIntent`와 같은 모양이지만
/// 출처 배지가 Siri로 남는다 — 출처는 절대 속이지 않는다 (spec §5).
struct SiriAddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Siri로 기록"
    static let description = IntentDescription(
        "Siri에게 말해서 앱을 열지 않고 할 일을 빠른 기록에 남깁니다.",
        categoryName: "빠른 기록"
    )
    static let openAppWhenRun = false

    @Parameter(title: "제목", requestValueDialog: "무엇을 기록할까요?")
    var taskTitle: String

    @Parameter(title: "분면", description: "비워 두면 정리 전에 담겨요")
    var quadrant: QuadrantOption?

    @Parameter(title: "메모")
    var note: String?

    @Parameter(title: "날짜")
    var dueDate: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$taskTitle) 빠르게 기록") {
            \.$quadrant
            \.$note
            \.$dueDate
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let item = captureFromSystemSurface(
            title: taskTitle,
            quadrant: quadrant,
            note: note,
            dueDate: dueDate,
            source: .siri
        ) else {
            throw $taskTitle.needsValueError("무엇을 기록할까요?")
        }
        return .result(dialog: captureDialog(title: item.title, quadrant: quadrant))
    }
}

// MARK: - 액션 버튼 (spec §6.2)

/// 액션 버튼에 지정해 쓰는 빠른 기록. iPhone 설정 → 액션 버튼에서 단축어로
/// 이 동작을 고르면, 버튼 한 번으로 앱을 열지 않고 기록할 수 있다.
struct ActionButtonCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "액션 버튼으로 기록"
    static let description = IntentDescription(
        "iPhone 설정 → 액션 버튼에서 '단축어'로 이 동작을 지정하면, 버튼 한 번으로 앱을 열지 않고 할 일을 빠른 기록에 남길 수 있어요.",
        categoryName: "빠른 기록"
    )
    static let openAppWhenRun = false

    @Parameter(title: "제목", requestValueDialog: "무엇을 기록할까요?")
    var taskTitle: String

    @Parameter(title: "분면", description: "비워 두면 정리 전에 담겨요")
    var quadrant: QuadrantOption?

    @Parameter(title: "메모")
    var note: String?

    @Parameter(title: "날짜")
    var dueDate: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$taskTitle) 빠르게 기록") {
            \.$quadrant
            \.$note
            \.$dueDate
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let item = captureFromSystemSurface(
            title: taskTitle,
            quadrant: quadrant,
            note: note,
            dueDate: dueDate,
            source: .actionButton
        ) else {
            throw $taskTitle.needsValueError("무엇을 기록할까요?")
        }
        return .result(dialog: captureDialog(title: item.title, quadrant: quadrant))
    }
}
