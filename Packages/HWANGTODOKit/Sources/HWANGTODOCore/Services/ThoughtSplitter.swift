import Foundation

/// Deterministic Korean sentence → task-candidate splitter for 나와의 채팅.
///
/// This is rule-based extraction, NOT an AI model — the UI must call it
/// "할 일로 정리" / "추천 추출", never "AI 분석" (spec §12).
///
/// Canonical example (spec §12):
///   "오늘 업무일지 쓰고, 캘린더 확인하고, 엄마한테 전화해야 함"
///   → ["업무일지 쓰기", "캘린더 확인하기", "엄마한테 전화하기"]
nonisolated public enum ThoughtSplitter {
    /// Splits free-form text into cleaned task candidates. Deduplicates while
    /// preserving order; drops fragments shorter than 2 characters.
    public static func candidates(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "\n;,·•")
        let fragments = text
            .replacingOccurrences(of: " 그리고 ", with: "\n")
            .components(separatedBy: separators)

        var seen = Set<String>()
        var results: [String] = []
        for fragment in fragments {
            let cleaned = normalize(fragment)
            guard cleaned.count >= 2, !seen.contains(cleaned) else { continue }
            seen.insert(cleaned)
            results.append(cleaned)
        }
        return results
    }

    /// Normalizes one clause into a task-shaped phrase.
    static func normalize(_ fragment: String) -> String {
        var text = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        text = stripLeadingFillers(text)
        text = trimTrailingPunctuation(text)
        text = convertEnding(text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Leading time/filler words that don't belong in a task title.
    private static let leadingFillers = ["오늘 ", "내일 ", "이따가 ", "이따 ", "나중에 ", "그리고 ", "또 ", "먼저 "]

    private static func stripLeadingFillers(_ text: String) -> String {
        var result = text
        var changed = true
        while changed {
            changed = false
            for filler in leadingFillers where result.hasPrefix(filler) {
                result = String(result.dropFirst(filler.count))
                changed = true
            }
        }
        return result
    }

    private static func trimTrailingPunctuation(_ text: String) -> String {
        var result = text
        while let last = result.last, ".!?~ 　".contains(last) {
            result.removeLast()
        }
        return result
    }

    /// Obligation/connective endings → the neutral "-기" task form.
    /// Ordered longest-first so the most specific pattern wins.
    private static let endingRules: [(suffix: String, replacement: String)] = [
        ("해야 한다", "하기"), ("해야 함", "하기"), ("해야함", "하기"),
        ("해야 해", "하기"), ("해야해", "하기"), ("해야지", "하기"),
        ("해야겠다", "하기"), ("해야 됨", "하기"), ("해야됨", "하기"),
        ("해야 돼", "하기"), ("해야돼", "하기"), ("해야", "하기"),
        ("할 것", "하기"), ("할것", "하기"), ("하자", "하기"),
        ("할 예정", "하기"), ("해야겠음", "하기"),
        ("하고", "하기"),
    ]

    /// Common nouns ending in 고 — the generic connective rule must never
    /// touch these ("업무 보고" is a report, not "업무 보기").
    private static let nounsEndingInGo: Set<String> = [
        "보고", "광고", "사고", "재고", "창고", "금고", "참고", "신고", "경고", "원고", "비고",
    ]

    private static func convertEnding(_ text: String) -> String {
        for rule in endingRules where text.hasSuffix(rule.suffix) {
            return String(text.dropLast(rule.suffix.count)) + rule.replacement
        }
        // Generic connective "-고" ("쓰고" → "쓰기") — but only when the final
        // word is not itself a 고-final noun.
        if text.hasSuffix("고"), text.count >= 2 {
            let lastWord = text.split(separator: " ").last.map(String.init) ?? text
            guard !nounsEndingInGo.contains(lastWord) else { return text }
            return String(text.dropLast()) + "기"
        }
        // Already task-shaped ("업무일지 쓰기") or a plain noun phrase — leave as captured.
        return text
    }
}
