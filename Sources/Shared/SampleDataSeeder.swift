import Foundation

/// Seeds a small, realistic demo set ONCE, guarded by a flag in the shared App
/// Group UserDefaults. Never re-seeds on later launches. This is the only place
/// sample data is created — production launches keep whatever the user captured.
enum SampleDataSeeder {

    private static let hasSeededKey = "hasSeededSampleData_v3"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    static func seedIfNeeded() {
        guard !defaults.bool(forKey: hasSeededKey) else { return }
        seed()
        defaults.set(true, forKey: hasSeededKey)
    }

    /// Settings-triggered reset (explicit, safe).
    static func reset() {
        seed()
        defaults.set(true, forKey: hasSeededKey)
    }

    private static func seed() {
        let now = Date.now
        func at(_ minutesAgo: Int) -> Date { now.addingTimeInterval(TimeInterval(-minutesAgo * 60)) }

        let tasks: [MatrixTask] = [
            MatrixTask(title: "TokenForge 레이아웃 이슈 확인", createdAt: at(8), updatedAt: at(8),
                       status: .active, quadrant: .urgentImportant, priority: .high, source: .actionButton),
            MatrixTask(title: "LoroTopik SSO 정리", createdAt: at(20), updatedAt: at(20),
                       status: .active, quadrant: .importantNotUrgent,
                       dueDate: Calendar.current.date(byAdding: .day, value: 2, to: now), source: .siri),
            MatrixTask(title: "업무일지 작성", createdAt: at(35), updatedAt: at(35),
                       status: .active, quadrant: .importantNotUrgent, source: .shortcut),
            MatrixTask(title: "카드 명세서 확인", createdAt: at(50), updatedAt: at(50),
                       status: .active, quadrant: .urgentNotImportant, source: .app),
            MatrixTask(title: "헤어왁스 사기", createdAt: at(65), updatedAt: at(65),
                       status: .active, quadrant: .notUrgentNotImportant, source: .homeWidget),
            MatrixTask(title: "엄마한테 전화하기", createdAt: at(5), updatedAt: at(5),
                       status: .inbox, quadrant: .unassigned, source: .lockScreenWidget),
            MatrixTask(title: "AX 워크플로 자동화 아이디어", createdAt: at(12), updatedAt: at(12),
                       status: .inbox, quadrant: .unassigned, source: .selfChat)
        ]
        TaskStore.shared.saveTasks(tasks)

        let routines: [Routine] = [
            Routine(title: "물 마시기", weekdays: [], createdAt: at(120)),
            Routine(title: "운동하기", weekdays: [2, 4, 6], createdAt: at(120)),
            Routine(title: "퇴근 전 정리", weekdays: [2, 3, 4, 5, 6],
                    defaultQuadrant: .importantNotUrgent, createdAt: at(120))
        ]
        TaskStore.shared.saveRoutines(routines)

        let chat: [ChatMessage] = [
            ChatMessage(text: "오늘 업무일지 쓰고, 캘린더 확인하고, 엄마한테 전화해야 함", createdAt: at(40))
        ]
        TaskStore.shared.saveChat(chat)
    }
}
