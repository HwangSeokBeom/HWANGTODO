import Foundation
import HWANGTODOCore
import SwiftData
import Testing

/// TodoRepository behavior over an isolated in-memory store. Each test builds
/// its own container so tests never share state (and never touch the real
/// App Group store).
@Suite("TodoRepository — 저장소 규칙")
@MainActor
struct RepositoryTests {
    /// Fresh in-memory stack per test. The repository must OWN the container —
    /// ModelContext does not retain it, and an unowned container deallocates
    /// at the end of this function, trapping on the first save.
    private func makeRepository() throws -> TodoRepository {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SharedStore.schema, configurations: configuration)
        return TodoRepository(container: container)
    }

    // MARK: - Capture (the product's core promise)

    @Test("빈 제목은 저장하지 않음, 공백은 정리")
    func captureTrimsAndRejectsEmpty() throws {
        let repository = try makeRepository()

        #expect(repository.capture("") == nil)
        #expect(repository.capture("   \n  ") == nil)
        #expect(repository.items.isEmpty)

        let item = try #require(repository.capture("  운동 계획 세우기  "))
        #expect(item.title == "운동 계획 세우기")
    }

    /// Capture never demands organization: no quadrant → 정리 전 (`inbox`);
    /// an explicit quadrant → straight to `active`.
    @Test("분면 없으면 정리 전, 있으면 진행 중")
    func captureStatusFollowsQuadrant() throws {
        let repository = try makeRepository()

        let plain = try #require(repository.capture("빠르게 남긴 일"))
        #expect(plain.status == .inbox)
        #expect(plain.quadrant == .unassigned)

        let organized = try #require(repository.capture("회의 자료 마무리", quadrant: .urgentImportant))
        #expect(organized.status == .active)
        #expect(organized.quadrant == .urgentImportant)

        let explicitlyUnassigned = try #require(repository.capture("나중에 정리할 일", quadrant: .unassigned))
        #expect(explicitlyUnassigned.status == .inbox)
    }

    /// Capture-source honesty: the stored source is exactly what the surface passed.
    @Test("캡처 출처는 전달한 값 그대로")
    func captureKeepsTrueSource() throws {
        let repository = try makeRepository()
        let item = try #require(repository.capture("Siri로 남긴 일", source: .siri))
        #expect(item.source == .siri)
    }

    // MARK: - markDone

    @Test("완료 처리: completedAt 기록 + taskCompleted 훅 발화")
    func markDoneSetsCompletedAtAndFiresHook() throws {
        let repository = try makeRepository()
        var completedID: UUID?
        repository.hooks.taskCompleted = { completedID = $0.id }

        let item = try #require(repository.capture("은행 서류 제출"))
        repository.markDone(item)

        #expect(item.status == .done)
        #expect(item.completedAt != nil)
        #expect(completedID == item.id)
    }

    // MARK: - assign

    /// Moving a task back to 정리 전 must also revert its lifecycle status.
    @Test("미지정 분면으로 되돌리면 상태도 정리 전")
    func assignToUnassignedRevertsToInbox() throws {
        let repository = try makeRepository()
        let item = try #require(repository.capture("책 반납하기", quadrant: .urgentNotImportant))
        #expect(item.status == .active)

        repository.assign(item, to: .unassigned)
        #expect(item.status == .inbox)
        #expect(item.quadrant == .unassigned)

        repository.assign(item, to: .importantNotUrgent)
        #expect(item.status == .active)
    }

    // MARK: - convertToRoutine

    @Test("루틴으로 만들기: 원본 제거, 분면 승계, taskRemoved 훅")
    func convertToRoutineRemovesTaskAndCarriesQuadrant() throws {
        let repository = try makeRepository()
        var removedID: UUID?
        repository.hooks.taskRemoved = { removedID = $0 }

        let item = try #require(repository.capture("업무일지 작성", quadrant: .importantNotUrgent))
        let itemID = item.id

        let routine = repository.convertToRoutine(item, weekdays: [2, 4])

        #expect(repository.task(withID: itemID) == nil)
        #expect(routine.title == "업무일지 작성")
        #expect(routine.weekdays == [2, 4])
        #expect(routine.defaultQuadrant == .importantNotUrgent)
        #expect(removedID == itemID)
        #expect(repository.routines.contains { $0.id == routine.id })
    }

    /// 정리 전 tasks convert with no quadrant — unassigned never leaks into routines.
    @Test("미지정 할 일은 분면 없이 루틴화")
    func convertUnassignedTaskYieldsNoQuadrant() throws {
        let repository = try makeRepository()
        let item = try #require(repository.capture("물 마시기"))
        let routine = repository.convertToRoutine(item)
        #expect(routine.defaultQuadrant == nil)
    }

    // MARK: - 나와의 채팅 conversion

    /// Re-converting the same entry with the same titles must be a no-op —
    /// the dedup guard keys on already-converted task titles.
    @Test("같은 제목 재변환은 중복 생성하지 않음")
    func chatConvertDeduplicatesOnSecondCall() throws {
        let repository = try makeRepository()
        let entry = try #require(repository.addChatEntry("오늘 업무일지 쓰고, 캘린더 확인하고, 엄마한테 전화해야 함"))
        let titles = ["업무일지 쓰기", "캘린더 확인하기", "엄마한테 전화하기"]

        let first = repository.convert(entry, titles: titles)
        #expect(first.count == 3)
        // 나와의 채팅 conversions carry the honest source badge.
        #expect(first.allSatisfy { $0.source == .selfChat })

        let second = repository.convert(entry, titles: titles)
        #expect(second.isEmpty)
        #expect(repository.items.count == 3)
        #expect(entry.convertedTaskIDs.count == 3)
    }

    /// The dedup key is the title AS CONVERTED — renaming or deleting the
    /// created task must not reopen the hole on a later re-convert.
    @Test("변환된 할 일을 고치거나 지워도 재변환은 중복 생성하지 않음")
    func chatConvertSurvivesRenameAndDelete() throws {
        let repository = try makeRepository()
        let entry = try #require(repository.addChatEntry("업무일지 쓰고 엄마한테 전화해야 함"))
        let titles = ["업무일지 쓰기", "엄마한테 전화하기"]

        let created = repository.convert(entry, titles: titles)
        #expect(created.count == 2)

        // Rename one converted task, delete the other.
        repository.setTitle(created[0], "업무일지 마무리")
        repository.delete(created[1])

        let again = repository.convert(entry, titles: titles)
        #expect(again.isEmpty, "제목 변경/삭제 후에도 '이미 정리한 항목은 다시 담기지 않아요' 약속이 지켜져야 한다")
        #expect(repository.items.count == 1)
    }

    /// Two candidates edited to the same text in one 담기 create one task.
    @Test("한 번의 변환 안에서 같은 제목은 한 번만 생성")
    func chatConvertDeduplicatesWithinOneCall() throws {
        let repository = try makeRepository()
        let entry = try #require(repository.addChatEntry("우유 사고 우유 사기"))

        let created = repository.convert(entry, titles: ["우유 사기", "우유 사기", "  우유 사기  "])
        #expect(created.count == 1)
        #expect(repository.items.count == 1)
    }

    // MARK: - dailyProgress

    /// Denominator: tasks due today (open or done) + routines scheduled today.
    /// Archived tasks disappear from the math entirely.
    @Test("오늘 진행률에서 지난 기록은 제외")
    func dailyProgressExcludesArchived() throws {
        let repository = try makeRepository()

        _ = try #require(repository.capture("열린 할 일", dueDate: .now))
        let done = try #require(repository.capture("끝낸 할 일", dueDate: .now))
        repository.markDone(done)
        let archived = try #require(repository.capture("지난 할 일", dueDate: .now))
        repository.archive(archived)

        // A daily routine joins the denominator; it is not completed today.
        _ = try #require(repository.addRoutine(title: "물 마시기"))

        let progress = repository.dailyProgress()
        #expect(progress.done == 1)
        #expect(progress.total == 3)
    }

    // MARK: - Display order

    /// The one canonical list order: pinned first, then newest first.
    @Test("고정 우선, 최신 우선 정렬")
    func displaySortedIsPinnedFirstNewestFirst() throws {
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        let older = TodoItem(title: "오래된 일", createdAt: base)
        let newer = TodoItem(title: "새로운 일", createdAt: base.addingTimeInterval(3_600))
        let pinnedOld = TodoItem(title: "고정된 일", createdAt: base.addingTimeInterval(-3_600), isPinned: true)

        let sorted = [older, newer, pinnedOld].displaySorted()
        #expect(sorted.map(\.title) == ["고정된 일", "새로운 일", "오래된 일"])

        // The repository serves the same order from the store.
        let repository = try makeRepository()
        [older, newer, pinnedOld].forEach(repository.context.insert)
        try repository.context.save()
        repository.reload()
        #expect(repository.items.map(\.title) == ["고정된 일", "새로운 일", "오래된 일"])
    }
}
