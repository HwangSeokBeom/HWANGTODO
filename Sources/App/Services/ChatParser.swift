import Foundation

/// Deterministic (no AI) splitter that turns a free-form self-chat line into
/// candidate task titles. Honest and predictable. Handles Korean and English.
struct ChatParser {

    func taskTitles(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ".\n;")
        let sentences = text.components(separatedBy: separators)

        var parts: [String] = []
        for sentence in sentences {
            // Split on conjunctions: English "and", Korean "그리고" and the
            // connective "고," / "하고," patterns common in casual Korean.
            let chunk = sentence
                .replacingOccurrences(of: " 그리고 ", with: "§")
                .replacingOccurrences(of: "하고,", with: "하기§")
                .replacingOccurrences(of: "고,", with: "기§")
                .replacingOccurrences(of: ",", with: "§")
                .replacingOccurrences(of: " and ", with: "§")
            parts.append(contentsOf: chunk.components(separatedBy: "§"))
        }

        let cleaned = parts.map { clean($0) }.filter { $0.count >= 2 }
        var seen = Set<String>()
        return cleaned.filter { seen.insert($0.lowercased()).inserted }
    }

    private func clean(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip leading time/filler words (Korean + English).
        let prefixes = [
            "오늘 ", "내일 ", "이번 주 ", "tomorrow i need to ", "today i need to ",
            "i need to ", "i have to ", "need to ", "remember to "
        ]
        let lower = s.lowercased()
        for p in prefixes where lower.hasPrefix(p) { s = String(s.dropFirst(p.count)); break }

        // Strip trailing Korean obligation endings to leave a clean task title.
        for suffix in ["해야 함", "해야함", "해야 됨", "해야돼", "하기", "해야 한다"] where s.hasSuffix(suffix) {
            s = String(s.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        s = s.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return s }

        // Normalise to a Korean task phrase ending in "하기" when it looks like a verb.
        if let last = s.unicodeScalars.last, last.value >= 0xAC00, last.value <= 0xD7A3 {
            return s + "하기"
        }
        // English: capitalise first letter.
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
