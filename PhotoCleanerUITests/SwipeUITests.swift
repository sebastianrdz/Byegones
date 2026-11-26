import XCTest

@MainActor
final class SwipeUITests: ByegonesUITestCase {
    override func setUp() async throws {
        try await super.setUp()
        launchReady()
        requireRemaining(atLeast: 8)
    }

    func testSwipeRightKeepsAndAdvancesWithoutTouchingThePile() {
        let before = remaining
        swipeCard(.right)
        waitForRemaining(before - 1)
        XCTAssertEqual(pileCount, 0)
        XCTAssertTrue(button("Undo").isEnabled, "Undo should become available after a decision")
    }

    func testSwipeLeftSendsToTrashPileAndUpdatesCounterAndPill() {
        let before = remaining
        swipeCard(.left)
        waitForRemaining(before - 1)
        waitForPile(1)
        XCTAssertTrue(trashPill.label.contains("Opens review"))
        swipeCard(.left)
        waitForRemaining(before - 2)
        waitForPile(2)
    }

    func testSwipeUpFavoritesAndAdvances() {
        let before = remaining
        swipeCard(.up)
        waitForRemaining(before - 1)
        XCTAssertEqual(pileCount, 0, "Favorite keeps the item; it must not enter the pile")
        XCTAssertTrue(app.state == .runningForeground, "App must survive the Photos favorite write")
        sleep(2)   // the write is fire and forget; give a crash time to show
        XCTAssertTrue(app.state == .runningForeground, "App crashed after the Photos favorite write")
    }

    func testActionButtonsMatchGestures() {
        let before = remaining
        button("Keep").tap()
        waitForRemaining(before - 1)
        button("Delete").tap()
        waitForRemaining(before - 2)
        waitForPile(1)
        button("Favorite").tap()
        waitForRemaining(before - 3)
        waitForPile(1)
    }

    func testUndoRestoresTheLastDecisionInEachKind() {
        XCTAssertFalse(button("Undo").isEnabled, "Nothing to undo on a fresh state")
        let start = remaining

        swipeCard(.left)
        waitForPile(1)
        button("Undo").tap()
        waitForRemaining(start)
        waitForPile(0)

        swipeCard(.right)
        waitForRemaining(start - 1)
        button("Undo").tap()
        waitForRemaining(start)

        swipeCard(.up)
        waitForRemaining(start - 1)
        button("Undo").tap()
        waitForRemaining(start)
        XCTAssertFalse(button("Undo").isEnabled, "History is empty again")
    }

    func testUndoWalksBackThroughSeveralDecisions() {
        let start = remaining
        button("Keep").tap(); waitForRemaining(start - 1)
        button("Delete").tap(); waitForRemaining(start - 2)
        button("Keep").tap(); waitForRemaining(start - 3)
        for expected in [start - 2, start - 1, start] {
            button("Undo").tap()
            waitForRemaining(expected)
        }
        waitForPile(0)
    }

    func testCardIsOneAccessibilityElementAndTheFourActionsAreLabelled() {
        // Exactly one card element, labelled with kind and date (VoiceOver reads this).
        let cards = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Photo,' OR label BEGINSWITH 'Video,'"))
        XCTAssertEqual(cards.count, 1)
        XCTAssertTrue(cards.firstMatch.label.contains(","))
        for label in ["Keep", "Delete", "Favorite", "Undo", "Settings"] {
            XCTAssertTrue(button(label).exists, "Missing button \(label)")
        }
        XCTAssertTrue(counter.exists)
        XCTAssertTrue(trashPill.exists)
        // LIMIT: the card's accessibilityActions (Keep, Delete, Favorite, Undo) and its hint are not
        // exposed by XCUITest, so they cannot be invoked or asserted here. They share
        // CardController.perform with the buttons exercised above.
    }

    func testProgressSurvivesRelaunch() {
        let start = remaining
        swipeCard(.right)           // kept
        waitForRemaining(start - 1)
        swipeCard(.left)            // trash pile
        waitForRemaining(start - 2)
        waitForPile(1)

        relaunch()
        waitForRemaining(start - 2)
        waitForPile(1)
        XCTAssertFalse(button("Undo").isEnabled, "Undo history is session-only and is gone after relaunch")
    }
}
