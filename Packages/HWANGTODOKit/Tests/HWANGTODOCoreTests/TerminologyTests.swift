import Foundation
import HWANGTODOCore
import Testing

/// 용어 규칙 (spec §14). Two guarantees:
///  1. The banned mailbox words never appear in any shipped Swift source —
///     the source tree is scanned on every test run, so a regression in ANY
///     track fails here.
///  2. The `Terminology` constants and `Quadrant` titles match the spec's
///     recommended vocabulary verbatim.
@Suite("Terminology — 용어 규칙")
struct TerminologyTests {
    /// Banned words, assembled at runtime so this file itself never contains
    /// them as contiguous literals.
    nonisolated private static let bannedWords = ["받은" + "함", "보관" + "함"]

    /// Repo root derived from this file's location:
    /// …/Packages/HWANGTODOKit/Tests/HWANGTODOCoreTests/TerminologyTests.swift
    nonisolated private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // HWANGTODOCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // HWANGTODOKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo root

    /// All shipped Swift sources: the app/widget tree and the package tree.
    /// (Tests and Docs are not shipped and are not scanned.)
    private func shippedSwiftFiles() throws -> [URL] {
        let roots = [
            Self.repoRoot.appendingPathComponent("Sources", isDirectory: true),
            Self.repoRoot.appendingPathComponent("Packages/HWANGTODOKit/Sources", isDirectory: true),
        ]
        var files: [URL] = []
        for root in roots {
            try #require(
                FileManager.default.fileExists(atPath: root.path),
                "소스 루트를 찾지 못함: \(root.path) — #filePath 기준 경로 계산 확인 필요"
            )
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                files.append(url)
            }
        }
        return files
    }

    /// No shipped source may contain a banned word. Sole exception:
    /// `Terminology.swift` documents the ban list itself, so there (and only
    /// there) the words may appear on comment lines — never in code or string
    /// literals.
    @Test("금지어(받은함·보관함)가 소스에 없음")
    func noBannedWordsInShippedSources() throws {
        let files = try shippedSwiftFiles()
        try #require(!files.isEmpty, "스캔할 Swift 파일이 하나도 없음 — 경로 계산이 틀렸을 가능성")

        var violations: [String] = []
        for file in files {
            guard let contents = try? String(contentsOf: file, encoding: .utf8) else {
                violations.append("\(file.lastPathComponent): 읽기 실패")
                continue
            }
            let isBanListDefinition = file.lastPathComponent == "Terminology.swift"
            for (index, line) in contents.components(separatedBy: "\n").enumerated() {
                guard Self.bannedWords.contains(where: line.contains) else { continue }
                let isCommentLine = line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
                if isBanListDefinition, isCommentLine { continue }
                violations.append("\(file.lastPathComponent):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        #expect(violations.isEmpty, "금지어 발견:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - Vocabulary constants (spec §14, §4, §5)

    @Test("탭 이름 (spec §4)")
    func tabNamesMatchSpec() {
        #expect(Terminology.tabCapture == "기록")
        #expect(Terminology.tabOrganize == "정리")
        #expect(Terminology.tabSchedule == "일정")
        #expect(Terminology.tabRoutine == "루틴")
        #expect(Terminology.tabSettings == "설정")
    }

    @Test("빠른 기록 화면 문구 (spec §5)")
    func captureHomeVocabularyMatchesSpec() {
        #expect(Terminology.quickCapture == "빠른 기록")
        #expect(Terminology.quickCaptureSubtitle == "앱을 열지 않고 남긴 할 일이 모이는 곳")
        #expect(Terminology.quickCapturePlaceholder == "지금 떠오른 일 빠르게 남기기")
        #expect(Terminology.pending == "정리 전")
        #expect(Terminology.completedItems == "완료한 일")
        #expect(Terminology.pastRecords == "지난 기록")
        #expect(Terminology.todayTasks == "오늘 할 일")
    }

    @Test("핵심 액션 문구 (spec §14)")
    func coreActionVocabularyMatchesSpec() {
        #expect(Terminology.doNow == "지금 하기")
        #expect(Terminology.scheduleIt == "일정 잡기")
        #expect(Terminology.makeRoutine == "루틴으로 만들기")
        #expect(Terminology.linkNote == "메모 연결")
        #expect(Terminology.startFocus == "집중 시작")
        #expect(Terminology.organizeLater == "나중에 정리")
        #expect(Terminology.organizeIntoTasks == "할 일로 정리")
        #expect(Terminology.captureWithoutOpening == "앱을 열지 않고 기록")
    }

    @Test("앱 핵심 문구 (spec §14)")
    func taglineMatchesSpec() {
        #expect(Terminology.tagline == "앱을 열지 않고 기록하세요.\n떠오른 일은 빠르게 남기고, 정리는 나중에 해도 괜찮아요.")
    }

    /// The friendly quadrant names are fixed vocabulary (spec §8) — synonyms
    /// are never allowed.
    @Test("분면 이름 (spec §8)")
    func quadrantTitlesMatchSpec() {
        #expect(Quadrant.urgentImportant.title == "지금 할 일")
        #expect(Quadrant.importantNotUrgent.title == "계획할 일")
        #expect(Quadrant.urgentNotImportant.title == "맡길 일")
        #expect(Quadrant.notUrgentNotImportant.title == "줄일 일")
        #expect(Quadrant.unassigned.title == "정리 전")
    }
}
