import Foundation
import HWANGTODOCore
import SwiftData
import Testing

/// LegacyJSONImporter safety rules: import exactly once, rename (never delete)
/// consumed files, and treat decode failures as "retry later" — never as
/// "nothing to import". Every test uses its own temp directory, its own
/// UserDefaults suite, and its own in-memory store.
@Suite("LegacyJSONImporter — 예전 JSON 이관")
@MainActor
struct LegacyImportTests {
    /// Frozen persisted key — the importer's once-per-install marker.
    /// Renaming it in source would re-import on every user's next launch.
    nonisolated private static let completedFlag = "legacyJSONImportCompleted_v1"

    /// Per-test sandbox: unique base dir + unique defaults suite + fresh store.
    private struct Sandbox {
        let baseURL: URL
        let suiteName: String
        let defaults: UserDefaults
        let container: ModelContainer
        var context: ModelContext { container.mainContext }

        func tearDown() {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: baseURL)
        }
    }

    private func makeSandbox() throws -> Sandbox {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let suiteName = "LegacyImportTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SharedStore.schema, configurations: configuration)
        return Sandbox(baseURL: baseURL, suiteName: suiteName, defaults: defaults, container: container)
    }

    private func write(_ json: String, to fileName: String, in sandbox: Sandbox) throws {
        try json.write(to: sandbox.baseURL.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
    }

    private func fileExists(_ fileName: String, in sandbox: Sandbox) -> Bool {
        FileManager.default.fileExists(atPath: sandbox.baseURL.appendingPathComponent(fileName).path)
    }

    private func isoDate(_ string: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: string))
    }

    // MARK: - Fixtures (legacy on-disk shapes, iso8601 dates)

    nonisolated private static let knownTaskID = "11111111-1111-1111-1111-111111111111"
    nonisolated private static let unknownRawTaskID = "22222222-2222-2222-2222-222222222222"
    nonisolated private static let routineID = "33333333-3333-3333-3333-333333333333"
    nonisolated private static let chatWithConversionsID = "44444444-4444-4444-4444-444444444444"
    nonisolated private static let chatMinimalID = "55555555-5555-5555-5555-555555555555"

    nonisolated private static let tasksJSON = """
    [
        {
            "id": "\(knownTaskID)",
            "title": "회의 자료 마무리",
            "body": "안건 정리",
            "createdAt": "2025-05-01T09:00:00Z",
            "updatedAt": "2025-05-02T10:30:00Z",
            "statusRaw": "active",
            "quadrantRaw": "urgentImportant",
            "priorityRaw": "high",
            "dueDate": "2025-05-03T09:00:00Z",
            "sourceRaw": "siri",
            "isPinned": true,
            "noteLinkURL": "https://example.com/note"
        },
        {
            "id": "\(unknownRawTaskID)",
            "title": "출처를 알 수 없는 일",
            "createdAt": "2025-05-01T12:00:00Z",
            "updatedAt": "2025-05-01T12:00:00Z",
            "statusRaw": "someFutureStatus",
            "quadrantRaw": "someFutureQuadrant",
            "priorityRaw": "someFuturePriority",
            "sourceRaw": "someFutureSurface",
            "isPinned": false
        }
    ]
    """

    nonisolated private static let routinesJSON = """
    [
        {
            "id": "\(routineID)",
            "title": "업무일지 작성",
            "weekdays": [2, 3, 4, 5, 6],
            "defaultQuadrantRaw": "importantNotUrgent",
            "completionDates": ["2025-05-01T00:00:00Z"]
        }
    ]
    """

    nonisolated private static let chatJSON = """
    [
        {
            "id": "\(chatWithConversionsID)",
            "text": "오늘 업무일지 쓰고, 캘린더 확인하고, 엄마한테 전화해야 함",
            "createdAt": "2025-05-01T08:00:00Z",
            "convertedTaskIDs": ["\(knownTaskID)"]
        },
        {
            "id": "\(chatMinimalID)",
            "text": "생각 정리만 한 줄",
            "createdAt": "2025-05-02T08:00:00Z"
        }
    ]
    """

    // MARK: - Happy path

    @Test("할 일·루틴·채팅 이관: 알려진 raw는 매핑, 모르는 raw는 기본값")
    func importsAllFilesWithRawMappingAndDefaults() throws {
        let sandbox = try makeSandbox()
        defer { sandbox.tearDown() }
        try write(Self.tasksJSON, to: "hwangtodo_tasks.json", in: sandbox)
        try write(Self.routinesJSON, to: "hwangtodo_routines.json", in: sandbox)
        try write(Self.chatJSON, to: "hwangtodo_chat.json", in: sandbox)

        LegacyJSONImporter.importIfNeeded(into: sandbox.context, baseURL: sandbox.baseURL, defaults: sandbox.defaults)

        #expect(sandbox.defaults.bool(forKey: Self.completedFlag))

        let tasks = try sandbox.context.fetch(FetchDescriptor<TodoItem>())
        #expect(tasks.count == 2)

        let known = try #require(tasks.first { $0.id == UUID(uuidString: Self.knownTaskID) })
        #expect(known.title == "회의 자료 마무리")
        #expect(known.note == "안건 정리")
        #expect(known.noteLinkURL == "https://example.com/note")
        #expect(known.status == .active)
        #expect(known.quadrant == .urgentImportant)
        #expect(known.priority == .high)
        #expect(known.source == .siri)
        #expect(known.isPinned)
        let expectedCreatedAt = try isoDate("2025-05-01T09:00:00Z")
        let expectedDueDate = try isoDate("2025-05-03T09:00:00Z")
        #expect(known.createdAt == expectedCreatedAt)
        #expect(known.dueDate == expectedDueDate)

        // Unknown raws from a newer (or corrupted) writer degrade to safe defaults.
        let unknown = try #require(tasks.first { $0.id == UUID(uuidString: Self.unknownRawTaskID) })
        #expect(unknown.status == .inbox)
        #expect(unknown.quadrant == .unassigned)
        #expect(unknown.priority == .none)
        #expect(unknown.source == .app)

        let routines = try sandbox.context.fetch(FetchDescriptor<Routine>())
        let routine = try #require(routines.first { $0.id == UUID(uuidString: Self.routineID) })
        #expect(routine.title == "업무일지 작성")
        #expect(routine.weekdays == [2, 3, 4, 5, 6])
        #expect(routine.isActive) // omitted `isActive` defaults to true
        #expect(routine.defaultQuadrant == .importantNotUrgent)
        #expect(routine.completedDays.count == 1)

        let entries = try sandbox.context.fetch(FetchDescriptor<ChatEntry>())
        #expect(entries.count == 2)
        let converted = try #require(entries.first { $0.id == UUID(uuidString: Self.chatWithConversionsID) })
        #expect(converted.convertedTaskIDs == [UUID(uuidString: Self.knownTaskID)])
        let minimal = try #require(entries.first { $0.id == UUID(uuidString: Self.chatMinimalID) })
        #expect(minimal.convertedTaskIDs.isEmpty) // omitted list defaults to []
    }

    /// Consumed files are renamed to `*.imported` — never deleted.
    @Test("성공 시 원본은 .imported로 이름 변경")
    func renamesConsumedFilesToImported() throws {
        let sandbox = try makeSandbox()
        defer { sandbox.tearDown() }
        try write(Self.tasksJSON, to: "hwangtodo_tasks.json", in: sandbox)
        try write(Self.routinesJSON, to: "hwangtodo_routines.json", in: sandbox)
        try write(Self.chatJSON, to: "hwangtodo_chat.json", in: sandbox)

        LegacyJSONImporter.importIfNeeded(into: sandbox.context, baseURL: sandbox.baseURL, defaults: sandbox.defaults)

        for name in ["hwangtodo_tasks.json", "hwangtodo_routines.json", "hwangtodo_chat.json"] {
            #expect(!fileExists(name, in: sandbox))
            #expect(fileExists("\(name).imported", in: sandbox))
        }
    }

    // MARK: - Failure safety

    /// A decode failure means "try again next launch": the completed flag must
    /// stay unset and the corrupt file must remain exactly where it was.
    @Test("깨진 JSON: 플래그 미설정, 파일 보존")
    func corruptJSONLeavesEverythingInPlace() throws {
        let sandbox = try makeSandbox()
        defer { sandbox.tearDown() }
        try write("{ this is not json ", to: "hwangtodo_tasks.json", in: sandbox)

        LegacyJSONImporter.importIfNeeded(into: sandbox.context, baseURL: sandbox.baseURL, defaults: sandbox.defaults)

        #expect(!sandbox.defaults.bool(forKey: Self.completedFlag))
        #expect(fileExists("hwangtodo_tasks.json", in: sandbox))
        #expect(!fileExists("hwangtodo_tasks.json.imported", in: sandbox))
        let imported = try sandbox.context.fetch(FetchDescriptor<TodoItem>())
        #expect(imported.isEmpty)
    }

    /// All-or-nothing: when ONE file is corrupt, the files that decoded fine
    /// must also stay in place un-renamed, and nothing may be durably saved —
    /// otherwise a retry next launch finds the good files consumed and the
    /// legacy data is lost forever.
    @Test("일부만 깨져도 전체 재시도: 정상 파일도 소비하지 않음")
    func partialCorruptionConsumesNothing() throws {
        let sandbox = try makeSandbox()
        defer { sandbox.tearDown() }
        try write(Self.tasksJSON, to: "hwangtodo_tasks.json", in: sandbox)
        try write("{ broken", to: "hwangtodo_routines.json", in: sandbox)

        LegacyJSONImporter.importIfNeeded(into: sandbox.context, baseURL: sandbox.baseURL, defaults: sandbox.defaults)

        #expect(!sandbox.defaults.bool(forKey: Self.completedFlag))
        // The GOOD file must be exactly where it was — not renamed away.
        #expect(fileExists("hwangtodo_tasks.json", in: sandbox))
        #expect(!fileExists("hwangtodo_tasks.json.imported", in: sandbox))
        #expect(fileExists("hwangtodo_routines.json", in: sandbox))
        // Nothing durable: simulate process death by discarding staged inserts.
        sandbox.context.rollback()
        let persisted = try sandbox.context.fetch(FetchDescriptor<TodoItem>())
        #expect(persisted.isEmpty)

        // Next launch with the routines file repaired imports everything.
        try write(Self.routinesJSON, to: "hwangtodo_routines.json", in: sandbox)
        LegacyJSONImporter.importIfNeeded(into: sandbox.context, baseURL: sandbox.baseURL, defaults: sandbox.defaults)
        #expect(sandbox.defaults.bool(forKey: Self.completedFlag))
        #expect(try sandbox.context.fetch(FetchDescriptor<TodoItem>()).count == 2)
    }

    /// Once the flag is set, later launches never touch newly appearing files.
    @Test("성공 후 두 번째 호출은 아무것도 하지 않음")
    func secondCallAfterSuccessIsNoOp() throws {
        let sandbox = try makeSandbox()
        defer { sandbox.tearDown() }
        try write(Self.tasksJSON, to: "hwangtodo_tasks.json", in: sandbox)

        LegacyJSONImporter.importIfNeeded(into: sandbox.context, baseURL: sandbox.baseURL, defaults: sandbox.defaults)
        #expect(sandbox.defaults.bool(forKey: Self.completedFlag))
        let countAfterFirst = try sandbox.context.fetch(FetchDescriptor<TodoItem>()).count
        #expect(countAfterFirst == 2)

        // A file that shows up later must be ignored — and left untouched.
        try write(Self.tasksJSON, to: "hwangtodo_tasks.json", in: sandbox)
        LegacyJSONImporter.importIfNeeded(into: sandbox.context, baseURL: sandbox.baseURL, defaults: sandbox.defaults)

        let countAfterSecond = try sandbox.context.fetch(FetchDescriptor<TodoItem>()).count
        #expect(countAfterSecond == countAfterFirst)
        #expect(fileExists("hwangtodo_tasks.json", in: sandbox))
    }
}
