import AppIntents
import Foundation
import HWANGTODOCore
import OSLog
import SwiftData
import WidgetKit

/// Interactive-widget checkmark: marks one task done in place (spec §6.6).
///
/// Runs in the widget-extension process, so it writes through
/// `SharedStore.context` directly and reloads timelines itself — the app
/// process picks the change up on its next foreground `reload()`.
struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "할 일 완료"
    static let description = IntentDescription("위젯에서 할 일을 바로 완료 처리합니다.")
    /// Widget-internal affordance — a raw UUID parameter is useless in the
    /// 단축어 app, so keep it out of the gallery.
    static let isDiscoverable = false

    static let log = Logger(subsystem: "com.hwangtodo.app", category: "CompleteTaskIntent")

    @Parameter(title: "할 일 ID")
    var id: String

    init() {}

    init(id: UUID) {
        self.id = id.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: id) else {
            Self.log.error("malformed task id: \(id, privacy: .public)")
            return .result()
        }
        var descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        let context = SharedStore.context
        guard let item = try? context.fetch(descriptor).first, item.isOpen else {
            // Already completed, archived, or deleted elsewhere — a stale
            // checkmark must never resurrect a closed task. Refresh instead.
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }
        item.status = .done
        item.completedAt = item.completedAt ?? .now
        item.updatedAt = .now
        do {
            try context.save()
        } catch {
            Self.log.error("save failed: \(error, privacy: .public)")
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
