import Foundation
import OSLog
import SwiftData

/// The one SwiftData stack shared by the app, the widget extension, and every
/// AppIntent. Backed by SQLite (WAL) inside the App Group container, so
/// concurrent writes from different processes are transactionally safe —
/// a capture from any system surface can never be lost to a torn file write.
///
/// Explicitly `@MainActor`: widget providers and intents (which may start off
/// the main actor) reach it with `await`.
@MainActor
public enum SharedStore {
    static let log = Logger(subsystem: "com.hwangtodo.app", category: "SharedStore")

    public static let schema = Schema([TodoItem.self, Routine.self, ChatEntry.self])

    /// The shared container. Created once per process.
    public static let container: ModelContainer = makeContainer()

    /// Main-actor context for app UI and intent handlers.
    public static var context: ModelContext { container.mainContext }

    /// App Group container URL. In a correctly signed build this never fails;
    /// failing silently would split the store between app and widgets, so in
    /// DEBUG we crash loudly instead.
    public nonisolated static func appGroupURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
    }

    static func makeContainer() -> ModelContainer {
        let configuration: ModelConfiguration
        if let groupURL = appGroupURL() {
            let storeURL = groupURL.appendingPathComponent("HWANGTODO.store")
            configuration = ModelConfiguration("HWANGTODO", schema: schema, url: storeURL)
        } else {
            assertionFailure("App Group \(AppGroup.identifier) unavailable — check signing/entitlements. Falling back to a local store; widgets will not see this data.")
            log.fault("App Group container missing; using local Application Support store")
            configuration = ModelConfiguration("HWANGTODO", schema: schema)
        }
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Never wipe user data to "recover". An in-memory store keeps the
            // process alive; the on-disk store stays untouched for diagnosis.
            assertionFailure("ModelContainer failed: \(error)")
            log.fault("ModelContainer failed (\(error, privacy: .public)); using in-memory store")
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [memory])
        }
    }
}
