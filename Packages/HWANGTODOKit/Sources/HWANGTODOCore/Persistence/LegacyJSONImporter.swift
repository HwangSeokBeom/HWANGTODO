import Foundation
import OSLog
import SwiftData

/// One-time importer for the pre-1.0 JSON store (`hwangtodo_tasks.json` …).
///
/// Safety rules:
///  * Source files are never deleted — successful import renames them to
///    `*.imported`; failures leave everything in place for the next launch.
///  * A decode failure is treated as "try again later", never as "nothing to
///    import".
public enum LegacyJSONImporter {
    static let log = Logger(subsystem: "com.hwangtodo.app", category: "LegacyImport")
    static let completedFlag = "legacyJSONImportCompleted_v1"

    /// Old on-disk model shapes, kept decode-compatible with the legacy store.
    nonisolated struct LegacyTask: Decodable {
        var id: UUID
        var title: String
        var body: String?
        var createdAt: Date
        var updatedAt: Date
        var statusRaw: String
        var quadrantRaw: String
        var priorityRaw: String
        var dueDate: Date?
        var reminderDate: Date?
        var calendarEventIdentifier: String?
        var noteLinkURL: String?
        var sourceRaw: String
        var isPinned: Bool
        var completedAt: Date?
        var archivedAt: Date?
    }

    nonisolated struct LegacyRoutine: Decodable {
        var id: UUID
        var title: String
        var weekdays: [Int]
        var isActive: Bool?
        var defaultQuadrantRaw: String?
        var createdAt: Date?
        var completionDates: [Date]?
    }

    nonisolated struct LegacyChatMessage: Decodable {
        var id: UUID
        var text: String
        var createdAt: Date
        var convertedTaskIDs: [UUID]?
    }

    /// Imports the legacy JSON store into `context` exactly once per install.
    /// Call at app launch, before any UI queries run.
    /// `baseURL`/`defaults` are injectable for tests.
    public static func importIfNeeded(
        into context: ModelContext,
        baseURL: URL? = nil,
        defaults: UserDefaults = AppGroup.defaults
    ) {
        guard !defaults.bool(forKey: completedFlag) else { return }
        guard let base = baseURL ?? SharedStore.appGroupURL() else {
            log.warning("App Group unavailable; skipping legacy import this launch")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let tasksImported = importFile(base.appendingPathComponent("hwangtodo_tasks.json"), decoder: decoder, as: [LegacyTask].self) { tasks in
            for legacy in tasks {
                context.insert(TodoItem(
                    id: legacy.id,
                    title: legacy.title,
                    note: legacy.body,
                    noteLinkURL: legacy.noteLinkURL,
                    createdAt: legacy.createdAt,
                    updatedAt: legacy.updatedAt,
                    status: TaskStatus(rawValue: legacy.statusRaw) ?? .inbox,
                    quadrant: Quadrant(rawValue: legacy.quadrantRaw) ?? .unassigned,
                    priority: TaskPriority(rawValue: legacy.priorityRaw) ?? .none,
                    dueDate: legacy.dueDate,
                    reminderDate: legacy.reminderDate,
                    calendarEventID: legacy.calendarEventIdentifier,
                    source: CaptureSource(rawValue: legacy.sourceRaw) ?? .app,
                    isPinned: legacy.isPinned,
                    completedAt: legacy.completedAt,
                    archivedAt: legacy.archivedAt
                ))
            }
        }

        let routinesImported = importFile(base.appendingPathComponent("hwangtodo_routines.json"), decoder: decoder, as: [LegacyRoutine].self) { routines in
            for legacy in routines {
                context.insert(Routine(
                    id: legacy.id,
                    title: legacy.title,
                    weekdays: legacy.weekdays,
                    isActive: legacy.isActive ?? true,
                    defaultQuadrant: legacy.defaultQuadrantRaw.flatMap(Quadrant.init(rawValue:)),
                    createdAt: legacy.createdAt ?? .now,
                    completedDays: legacy.completionDates ?? []
                ))
            }
        }

        let chatImported = importFile(base.appendingPathComponent("hwangtodo_chat.json"), decoder: decoder, as: [LegacyChatMessage].self) { messages in
            for legacy in messages {
                context.insert(ChatEntry(
                    id: legacy.id,
                    text: legacy.text,
                    createdAt: legacy.createdAt,
                    convertedTaskIDs: legacy.convertedTaskIDs ?? []
                ))
            }
        }

        guard case .imported(let taskURL) = tasksImported,
              case .imported(let routineURL) = routinesImported,
              case .imported(let chatURL) = chatImported else {
            // All-or-nothing: unsaved context inserts are discarded with the
            // process; every source file stays exactly where it was, so the
            // next launch retries from scratch. Never partially consume.
            log.error("Legacy import incomplete; will retry next launch")
            return
        }

        do {
            try context.save()
        } catch {
            log.error("Legacy import save failed: \(error, privacy: .public)")
            return
        }

        // Only after a durable save may the source files be retired — a crash
        // between decode and save must leave them importable.
        for url in [taskURL, routineURL, chatURL].compactMap({ $0 }) {
            let renamed = url.appendingPathExtension("imported")
            try? FileManager.default.removeItem(at: renamed)
            try? FileManager.default.moveItem(at: url, to: renamed)
        }
        defaults.set(true, forKey: completedFlag)
        log.info("Legacy JSON import completed")
    }

    /// One file's decode+insert result. `.imported(nil)` means "file absent —
    /// nothing to do"; the URL is carried so the caller can rename it only
    /// after the batch save succeeds.
    nonisolated enum FileOutcome {
        case imported(URL?)
        case failed
    }

    /// Decodes one file and stages inserts into the context. NEVER touches
    /// the file itself — renaming happens in the caller after the batch save.
    private static func importFile<T: Decodable>(
        _ url: URL,
        decoder: JSONDecoder,
        as type: T.Type,
        insert: (T) -> Void
    ) -> FileOutcome {
        guard FileManager.default.fileExists(atPath: url.path) else { return .imported(nil) }
        do {
            let data = try Data(contentsOf: url)
            insert(try decoder.decode(T.self, from: data))
            return .imported(url)
        } catch {
            log.error("Failed to import \(url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
            return .failed
        }
    }
}
