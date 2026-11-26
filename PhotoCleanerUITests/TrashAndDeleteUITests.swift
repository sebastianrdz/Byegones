import XCTest

@MainActor
final class TrashAndDeleteUITests: ByegonesUITestCase {
    override func setUp() async throws {
        try await super.setUp()
        launchReady()
        requireRemaining(atLeast: 8)
    }

    func testTrashSheetListsThePileAndUntrashRemovesOneItem() {
        let start = remaining
        swipeCard(.left); waitForPile(1)
        swipeCard(.left); waitForPile(2)
        swipeCard(.left); waitForPile(3)

        openTrash()
        XCTAssertEqual(trashCells.count, 3)
        XCTAssertTrue(app.buttons["Delete 3 items"].exists)

        trashCells.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Removed from pile"].waitForExistence(timeout: 5), "Removal toast missing")
        let cellsGone = NSPredicate { _, _ in self.trashCells.count == 2 }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: cellsGone, object: nil)], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["Delete 2 items"].exists)
        closeTrash()

        waitForPile(2)
        // The untrashed item counts as kept, so it does not come back to the queue.
        waitForRemaining(start - 3)
    }

    func testUndoToastPutsTheRemovedItemBackInThePile() {
        swipeCard(.left); waitForPile(1)
        swipeCard(.left); waitForPile(2)
        openTrash()
        trashCells.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Removed from pile"].waitForExistence(timeout: 5))
        // The swipe screen's Undo button is also in the tree, behind the sheet; tap the hittable one.
        let undos = app.buttons.matching(NSPredicate(format: "label == 'Undo'")).allElementsBoundByIndex
        guard let toastUndo = undos.first(where: { $0.isHittable }) else { return XCTFail("Toast Undo not hittable") }
        toastUndo.tap()
        let back = NSPredicate { _, _ in self.trashCells.count == 2 }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: back, object: nil)], timeout: 5), .completed)
        closeTrash()
        waitForPile(2)
    }

    /// A cell tapped and Delete tapped straight after: the rescued photo must not be in the batch.
    func testRescuedPhotoIsNotDeletedWhenDeleteIsTappedRightAfterTheTap() {
        swipeCard(.left); waitForPile(1)
        swipeCard(.left); waitForPile(2)
        swipeCard(.left); waitForPile(3)
        openTrash()
        XCTAssertEqual(trashCells.count, 3)

        trashCells.firstMatch.tap()
        // No waiting for the shrink animation: the button already speaks for the two that are left.
        let delete = app.buttons["Delete 2 items"]
        XCTAssertTrue(delete.waitForExistence(timeout: 2), "Delete should already count 2 items")
        delete.tap()

        guard let confirm = systemDeleteButton() else { return XCTFail("No system confirmation appeared") }
        // The alert's own text names the count ("Allow Byegones to delete 2 photos?"); the button is just "Delete".
        let alerts = [springboard, app].flatMap { $0.alerts.allElementsBoundByIndex }
        let alertText = alerts.flatMap { [$0.label] + $0.staticTexts.allElementsBoundByIndex.map(\.label) }.joined(separator: " | ")
        XCTAssertTrue(alertText.contains("delete 2 photo"), "The rescued photo must not be in the batch; the alert says: \(alertText)")
        confirm.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'cleared'")).firstMatch.waitForExistence(timeout: 15))
        app.buttons["Keep going"].tap()
        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        waitForPile(0)
    }

    func testEmptyTrashSheetShowsEmptyStateAndNoDeleteButton() {
        openTrash()
        XCTAssertTrue(app.staticTexts["Your pile is empty"].exists)
        XCTAssertEqual(trashCells.count, 0)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete '")).firstMatch.exists)
        closeTrash()
    }

    func testCancellingTheSystemConfirmationKeepsThePile() {
        let start = remaining
        swipeCard(.left); waitForPile(1)
        swipeCard(.left); waitForPile(2)
        openTrash()
        app.buttons["Delete 2 items"].tap()
        XCTAssertTrue(cancelSystemDelete(), "No system confirmation appeared (did the app crash? state=\(app.state.rawValue))")
        XCTAssertTrue(app.staticTexts["Nothing was deleted. Your pile is still here."].waitForExistence(timeout: 8))
        XCTAssertEqual(trashCells.count, 2)
        closeTrash()
        waitForPile(2)
        waitForRemaining(start - 2)
    }

    func testDeleteConfirmedBySystemShowsCelebrationAndEmptiesThePile() {
        let start = remaining
        swipeCard(.left); waitForPile(1)
        swipeCard(.left); waitForPile(2)
        openTrash()
        app.buttons["Delete 2 items"].tap()

        XCTAssertTrue(confirmSystemDelete(), "No system confirmation appeared (did the app crash? state=\(app.state.rawValue))")

        // Celebration: under 1 MB the hero is the item count, otherwise the size.
        let hero = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'cleared'")).firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Celebration did not appear")
        XCTAssertTrue(app.buttons["Keep going"].exists || app.buttons["Done"].exists)
        app.buttons["Keep going"].tap()

        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        waitForPile(0)
        // Deleted items were never in the queue, so the queue length is unchanged.
        waitForRemaining(start - 2)
        XCTAssertFalse(button("Undo").isEnabled, "Deleted items cannot be undone")

        // Lifetime total shows up in Settings.
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Total cleared"].waitForExistence(timeout: 5))
        app.navigationBars["Settings"].buttons["Done"].tap()
    }
}
