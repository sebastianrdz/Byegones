import XCTest

/// Interruptibility of the card motion: input during a fly-off is never dropped, and the last card
/// leaves the screen without taking the empty state down with it.
@MainActor
final class MotionUITests: RollawayUITestCase {
    override func setUp() async throws {
        try await super.setUp()
        launchReady()
        requireRemaining(atLeast: 8)
    }

    /// Three Keep taps with no waiting in between (each well under 150 ms after the previous
    /// one is issued) must advance exactly three cards, not one or two.
    func testThreeRapidKeepTapsAdvanceExactlyThreeCards() {
        let start = remaining
        let keep = button("Keep").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let began = Date()
        keep.tap()
        keep.tap()
        keep.tap()
        let elapsed = Date().timeIntervalSince(began)
        add(XCTAttachment(string: "3 taps issued in \(Int(elapsed * 1000)) ms"))
        waitForRemaining(start - 3)
        sleep(1)   // nothing late may land
        XCTAssertEqual(remaining, start - 3, "Exactly three cards must have advanced")
        XCTAssertEqual(pileCount, 0)
    }

    /// Undo while the Keep card is still flying out restores that same card.
    func testUndoDuringFlyOffRestoresTheFlyingCard() {
        let start = remaining
        button("Keep").tap()
        let undo = app.buttons["swipe.action.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        let enabled = NSPredicate { _, _ in undo.isEnabled }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: nil)], timeout: 2), .completed)
        undo.tap()
        waitForRemaining(start)
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        sleep(1)
        XCTAssertEqual(remaining, start, "Undo must restore the card, and nothing else may move")
        XCTAssertFalse(undo.isEnabled, "History is empty again")
    }

    /// The last card flies out, the empty state takes over, and the app is still alive.
    /// Uses Keep only: it never writes to the Photos library.
    func testSwipingTheLastCardShowsTheEmptyState() {
        let total = remaining
        XCTAssertLessThan(total, 120, "Refusing to walk a large library")
        for i in 1..<total {
            button("Keep").tap()
            waitForRemaining(total - i, timeout: 6)
        }
        XCTAssertEqual(remaining, 1)
        swipeCard(.right)
        XCTAssertTrue(app.staticTexts["All caught up!"].waitForExistence(timeout: 8), "Empty state never appeared")
        XCTAssertFalse(button("Keep").exists, "Action bar is hidden when nothing is left")
        sleep(1)
        XCTAssertEqual(app.state, .runningForeground, "App must survive the last card")
    }
}
