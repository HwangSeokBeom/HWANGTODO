import Foundation
import HWANGTODOCore
import Testing

/// Deep-link URL round-trips. Hosts are frozen (they live inside placed
/// widgets and scheduled notifications), so `parse(link.url)` must return the
/// original link for every case — forever.
@Suite("DeepLink — URL 왕복")
struct DeepLinkTests {
    /// Fixed UUID so the task round-trip is reproducible.
    private nonisolated static let taskID = UUID(uuidString: "6F9B25C4-6F0A-4D3B-9A3E-2C5D1B7A8E01")!

    /// Every representable deep link, including the query-carrying and
    /// path-carrying variants. Nonisolated: parameterized-test arguments are
    /// enumerated outside the suite's actor.
    private nonisolated static let allLinks: [DeepLink] = [
        .captureHome(showCompleted: false),
        .captureHome(showCompleted: true),
        .organize(quadrant: nil),
        .schedule,
        .routines,
        .settings,
        .capture(),
        .chat,
        .focus,
        .task(taskID),
    ] + Quadrant.allCases.map { .organize(quadrant: $0) }
        + CaptureSource.allCases.map { .capture(source: $0) }

    @Test("모든 케이스 왕복", arguments: allLinks)
    func roundTripsEveryCase(link: DeepLink) {
        #expect(DeepLink.parse(link.url) == link)
    }

    /// All URLs must carry the frozen custom scheme.
    @Test("생성된 URL은 앱 스킴 사용", arguments: allLinks)
    func builtURLsUseAppScheme(link: DeepLink) {
        #expect(link.url.scheme == AppGroup.urlScheme)
    }

    // MARK: - Rejections

    @Test("다른 스킴은 nil")
    func foreignSchemeIsRejected() throws {
        let https = try #require(URL(string: "https://inbox"))
        #expect(DeepLink.parse(https) == nil)

        let other = try #require(URL(string: "someapp://capture"))
        #expect(DeepLink.parse(other) == nil)
    }

    @Test("모르는 호스트는 nil")
    func garbageHostIsRejected() throws {
        let url = try #require(URL(string: "\(AppGroup.urlScheme)://nonsense"))
        #expect(DeepLink.parse(url) == nil)
    }

    /// A quadrant link with an unknown raw value degrades to the matrix
    /// overview, never crashes and never guesses a quadrant.
    @Test("잘못된 분면 raw는 .organize(nil)")
    func badQuadrantRawFallsBackToOverview() throws {
        let url = try #require(URL(string: "\(AppGroup.urlScheme)://quadrant/notAQuadrant"))
        #expect(DeepLink.parse(url) == .organize(quadrant: nil))
    }

    @Test("잘못된 task UUID는 nil")
    func badTaskUUIDIsRejected() throws {
        let url = try #require(URL(string: "\(AppGroup.urlScheme)://task/not-a-uuid"))
        #expect(DeepLink.parse(url) == nil)
    }
}
