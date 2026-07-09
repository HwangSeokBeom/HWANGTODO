import XCTest

/// The one end-to-end smoke the spec demands be seen, not assumed (§16):
/// really TYPE a capture, watch it land in 정리 전, complete it, and find it
/// under 완료한 일. XCTest because XCUIApplication automation is not available
/// to Swift Testing; the test method is @MainActor because every XCUI API is.
final class CaptureFlowUITests: XCTestCase {
    @MainActor
    func testCaptureAppearsInPendingThenCompletes() {
        continueAfterFailure = false
        let app = XCUIApplication()
        // DEBUG-only reset: empty store, onboarding marked done.
        app.launchArguments = ["-hwangtodo-uitest-reset"]
        app.launch()

        let title = "우유 사기"

        // 1. Capture through the always-visible quick-capture accessory.
        let field = app.textFields["지금 떠오른 일 빠르게 남기기"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "빠른 기록 입력창이 보여야 한다")
        field.tap()
        field.typeText(title + "\n")

        // 2. The capture lands in 정리 전 on the 기록 home.
        let card = app.staticTexts[title]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "기록한 할 일이 정리 전 목록에 보여야 한다")

        // 3. Leading full swipe = 완료.
        card.swipeRight()
        // Dismiss the keyboard focus if the swipe re-opened it.
        if app.buttons["완료"].waitForExistence(timeout: 2) {
            app.buttons["완료"].tap()
        }

        // 4. The task shows up under the 완료한 일 segment.
        let completedSegment = app.buttons["완료한 일"]
        XCTAssertTrue(completedSegment.waitForExistence(timeout: 5))
        completedSegment.tap()
        XCTAssertTrue(
            app.staticTexts[title].waitForExistence(timeout: 5),
            "완료한 할 일이 완료한 일 목록에 보여야 한다"
        )
    }
}
