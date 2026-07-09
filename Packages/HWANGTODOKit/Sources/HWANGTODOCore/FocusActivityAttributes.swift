#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// Live Matrix — the Live Activity showing the task currently in focus on the
/// lock screen and in the Dynamic Island (spec §7).
nonisolated public struct FocusActivityAttributes: ActivityAttributes, Sendable {
    nonisolated public struct ContentState: Codable, Hashable, Sendable {
        /// The task in focus (deep-link target — spec §7 "정확한 할 일로 이동").
        public var taskID: UUID
        public var title: String
        public var quadrantRaw: String
        /// Session start; the UI renders elapsed time from it.
        public var startedAt: Date
        /// Progress through the focus queue, e.g. 1/4.
        public var doneCount: Int
        public var totalCount: Int
        /// The next task after this one, if any.
        public var nextTitle: String?

        public init(
            taskID: UUID,
            title: String,
            quadrantRaw: String,
            startedAt: Date,
            doneCount: Int,
            totalCount: Int,
            nextTitle: String?
        ) {
            self.taskID = taskID
            self.title = title
            self.quadrantRaw = quadrantRaw
            self.startedAt = startedAt
            self.doneCount = doneCount
            self.totalCount = totalCount
            self.nextTitle = nextTitle
        }

        public var quadrant: Quadrant { Quadrant(rawValue: quadrantRaw) ?? .unassigned }
        public var progressLabel: String { "\(min(doneCount + 1, totalCount))/\(totalCount)" }
    }

    /// One focus session (stable across content updates).
    public var sessionID: UUID

    public init(sessionID: UUID = UUID()) {
        self.sessionID = sessionID
    }
}
#endif
