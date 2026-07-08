import Foundation
import HWANGTODOCore
import Testing

/// 나와의 채팅 → 할 일 후보 추출 (spec §12). ThoughtSplitter is deterministic,
/// rule-based extraction — these tests pin the canonical example and every
/// documented normalization rule.
@Suite("ThoughtSplitter — 할 일로 정리")
struct ThoughtSplitterTests {
    // MARK: - Canonical case (spec §12)

    /// The spec §12 example must pass verbatim — it is the product's promise.
    @Test("스펙 §12 대표 예시")
    func canonicalSpecExample() {
        let candidates = ThoughtSplitter.candidates(from: "오늘 업무일지 쓰고, 캘린더 확인하고, 엄마한테 전화해야 함")
        #expect(candidates == ["업무일지 쓰기", "캘린더 확인하기", "엄마한테 전화하기"])
    }

    // MARK: - Splitting

    @Test("줄바꿈으로 분리")
    func splitsOnNewlines() {
        let candidates = ThoughtSplitter.candidates(from: "우유 사기\n책 반납하기")
        #expect(candidates == ["우유 사기", "책 반납하기"])
    }

    @Test("' 그리고 ' 접속사로 분리")
    func splitsOnGeurigoConjunction() {
        let candidates = ThoughtSplitter.candidates(from: "청소하고 그리고 빨래해야지")
        #expect(candidates == ["청소하기", "빨래하기"])
    }

    // MARK: - Dedup & drops

    @Test("동일 항목은 한 번만 (원문 중복)")
    func deduplicatesVerbatimRepeats() {
        #expect(ThoughtSplitter.candidates(from: "우유 사기, 우유 사기") == ["우유 사기"])
    }

    /// Different endings that normalize to the same "-기" phrase collapse into one.
    @Test("정규화 후 중복도 한 번만")
    func deduplicatesAfterNormalization() {
        #expect(ThoughtSplitter.candidates(from: "운동하기, 운동해야 함") == ["운동하기"])
    }

    @Test("2자 미만 조각은 버림")
    func dropsFragmentsShorterThanTwoCharacters() {
        #expect(ThoughtSplitter.candidates(from: "아, 우유 사기") == ["우유 사기"])
    }

    @Test("빈 입력은 빈 결과")
    func emptyInputYieldsNothing() {
        #expect(ThoughtSplitter.candidates(from: "").isEmpty)
        #expect(ThoughtSplitter.candidates(from: "   \n  ").isEmpty)
    }

    // MARK: - Already task-shaped input stays untouched

    @Test("이미 '-기' 형태면 그대로")
    func keepsAlreadyTaskShapedPhrase() {
        #expect(ThoughtSplitter.candidates(from: "업무일지 쓰기") == ["업무일지 쓰기"])
    }

    @Test("명사구는 그대로")
    func keepsPlainNounPhrase() {
        #expect(ThoughtSplitter.candidates(from: "우유") == ["우유"])
    }

    /// 고-final nouns must survive the generic "-고 → -기" connective rule —
    /// "업무 보고" is a report, never "업무 보기".
    @Test("고로 끝나는 명사는 변형하지 않음", arguments: [
        ("내일 업무 보고", "업무 보고"),
        ("전단지 광고", "전단지 광고"),
        ("재고", "재고"),
        ("창고 정리하고", "창고 정리하기"),
    ])
    func keepsGoFinalNouns(input: String, expected: String) {
        #expect(ThoughtSplitter.candidates(from: input) == [expected])
    }

    // MARK: - Trailing punctuation

    @Test("끝 문장부호 제거")
    func trimsTrailingPunctuation() {
        #expect(ThoughtSplitter.candidates(from: "이메일 보내기!!") == ["이메일 보내기"])
        #expect(ThoughtSplitter.candidates(from: "엄마한테 전화해야 함.") == ["엄마한테 전화하기"])
        #expect(ThoughtSplitter.candidates(from: "빨래하자~") == ["빨래하기"])
    }

    // MARK: - Obligation endings → "-기"

    @Test("의무형 어미 변환", arguments: [
        ("운동해야 함", "운동하기"),
        ("운동해야지", "운동하기"),
        ("운동해야겠다", "운동하기"),
        ("운동하자", "운동하기"),
        ("보고서 제출해야 한다", "보고서 제출하기"),
    ])
    func convertsObligationEndings(input: String, expected: String) {
        #expect(ThoughtSplitter.candidates(from: input) == [expected])
    }

    // MARK: - Leading fillers

    @Test("앞머리 시간/군말 제거", arguments: [
        ("오늘 운동하기", "운동하기"),
        ("내일 병원 예약하기", "병원 예약하기"),
        ("나중에 책상 정리하기", "책상 정리하기"),
    ])
    func stripsLeadingFillers(input: String, expected: String) {
        #expect(ThoughtSplitter.candidates(from: input) == [expected])
    }

    /// Fillers strip repeatedly — "오늘 먼저 …" loses both prefixes.
    @Test("군말이 겹쳐도 모두 제거")
    func stripsStackedFillers() {
        #expect(ThoughtSplitter.candidates(from: "오늘 먼저 메일 확인하기") == ["메일 확인하기"])
    }
}
