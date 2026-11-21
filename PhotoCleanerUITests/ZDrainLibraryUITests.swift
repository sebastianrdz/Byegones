import XCTest

/// Opt-in: deletes EVERY photo in the simulator library, so it only runs with
/// `TEST_RUNNER_ROLLAWAY_DRAIN=1` and must be followed by scripts/seed-uitest-photos.sh.
/// Covers the path "last card decided -> All caught up -> review pile -> delete -> celebration (Done)".
@MainActor
final class ZDrainLibraryUITests: RollawayUITestCase {
    func testTrashingTheWholeLibraryEndsInAllCaughtUpThenCelebrationWithDone() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ROLLAWAY_DRAIN"] == "1", "Opt-in: set TEST_RUNNER_ROLLAWAY_DRAIN=1")
        launchReady()
        let total = remaining
        XCTAssertLessThan(total, 120, "Refusing to drain a large library")

        for i in 1...total {
            button("Delete").tap()
            if i < total { waitForRemaining(total - i, timeout: 6) }
        }
        XCTAssertTrue(app.staticTexts["All caught up!"].waitForExistence(timeout: 8))
        XCTAssertFalse(button("Keep").exists, "Action bar is hidden when nothing is left")
        waitForPile(total)

        app.buttons["Review trash pile"].tap()
        XCTAssertTrue(app.navigationBars["Trash pile"].waitForExistence(timeout: 5))
        app.buttons["Delete \(total) items"].tap()
        XCTAssertTrue(confirmSystemDelete(), "No system confirmation")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'cleared'")).firstMatch.waitForExistence(timeout: 20))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["No photos yet"].waitForExistence(timeout: 10))
    }
}
