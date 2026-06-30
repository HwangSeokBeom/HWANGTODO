import AppIntents
import WidgetKit

/// Quadrant choice exposed to Shortcuts/Siri (Korean).
enum QuadrantAppEnum: String, AppEnum {
    case urgentImportant, importantNotUrgent, urgentNotImportant, notUrgentNotImportant, unsorted

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "사분면")
    static var caseDisplayRepresentations: [QuadrantAppEnum: DisplayRepresentation] = [
        .urgentImportant: "급하고 중요함 (지금 하기)",
        .importantNotUrgent: "중요하지만 급하지 않음 (일정 잡기)",
        .urgentNotImportant: "급하지만 덜 중요함 (맡기기)",
        .notUrgentNotImportant: "줄이기 / 제거하기",
        .unsorted: "정리 전 (받은함)"
    ]

    var quadrant: MatrixQuadrant {
        switch self {
        case .urgentImportant: return .urgentImportant
        case .importantNotUrgent: return .importantNotUrgent
        case .urgentNotImportant: return .urgentNotImportant
        case .notUrgentNotImportant: return .notUrgentNotImportant
        case .unsorted: return .unassigned
        }
    }
}

/// The PRIMARY capture path. Runs from Siri, Shortcuts, the Action Button (via a
/// Shortcut), and Control Center WITHOUT opening the app. Writes straight to the
/// shared App Group store, so the task appears in 받은함/매트릭스 and widgets.
struct AddHWANGTODOTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "HWANGTODO에 할 일 추가"
    static var description = IntentDescription("할 일을 빠르게 받은함에 기록해요. 사분면·마감일·메모는 선택이에요.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "할 일", requestValueDialog: "무엇을 기록할까요?")
    var text: String

    @Parameter(title: "사분면")
    var quadrant: QuadrantAppEnum?

    @Parameter(title: "마감일")
    var dueDate: Date?

    @Parameter(title: "메모")
    var memo: String?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$text)을(를) HWANGTODO에 추가 \(\.$quadrant)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .result(value: "", dialog: "기록할 내용이 없어요.") }
        let q = quadrant?.quadrant ?? .unassigned
        TaskStore.shared.addTask(title: trimmed, quadrant: q, dueDate: dueDate, memo: memo, source: .shortcut)
        WidgetCenter.shared.reloadAllTimelines()
        let dest = q == .unassigned ? "받은함" : q.title
        return .result(value: trimmed, dialog: "\(dest)에 추가했어요.")
    }
}

/// Adds a line to the self-chat scratchpad (think-out-loud capture).
struct AddChatMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "HWANGTODO에 빠른 메모 추가"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "메모", requestValueDialog: "무슨 생각이에요?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .result(dialog: "추가할 내용이 없어요.") }
        TaskStore.shared.addChatMessage(trimmed)
        return .result(dialog: "채팅에 추가했어요.")
    }
}
