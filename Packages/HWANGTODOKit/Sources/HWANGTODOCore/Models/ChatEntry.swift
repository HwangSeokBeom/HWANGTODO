import Foundation
import SwiftData

/// One entry in 나와의 채팅 — a personal thinking space, not a chatbot
/// (spec §12). Entries can be split into task candidates; the resulting task
/// ids are recorded so re-converting never duplicates.
@Model
public final class ChatEntry {
    @Attribute(.unique) public var id: UUID
    public var text: String
    public var createdAt: Date
    /// Tasks already created from this entry (drives the "정리됨 n건" badge).
    public var convertedTaskIDs: [UUID]
    /// Candidate titles AT CONVERSION TIME — the dedup key for re-converting.
    /// Recorded separately from the task ids because tasks can be renamed or
    /// deleted afterwards; the promise "이미 정리한 항목은 다시 담기지 않아요"
    /// must survive both.
    ///
    /// Optional ON PURPOSE: this attribute was added after 1.0 shipped, and a
    /// non-optional array has no model-level default — lightweight migration
    /// of existing stores would fail ("missing attribute values on mandatory
    /// destination attribute"). Read through `titlesConvertedSoFar`.
    public var convertedTitles: [String]?

    public init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = .now,
        convertedTaskIDs: [UUID] = [],
        convertedTitles: [String]? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.convertedTaskIDs = convertedTaskIDs
        self.convertedTitles = convertedTitles
    }

    /// Migration-safe accessor for `convertedTitles`.
    public var titlesConvertedSoFar: [String] { convertedTitles ?? [] }

    public var hasConversions: Bool { !convertedTaskIDs.isEmpty }
}
