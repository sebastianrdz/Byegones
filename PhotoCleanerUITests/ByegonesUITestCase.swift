import XCTest

/// Shared plumbing for the end-to-end tests. They run against the real Photos library of the
/// simulator (seed it with scripts/seed-uitest-photos.sh) and never assume an exact photo count:
/// they read the counter and assert on deltas.
@MainActor
class ByegonesUITestCase: XCTestCase {
    let app = XCUIApplication()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() async throws {
        continueAfterFailure = false
    }

    // MARK: Launch

    /// `-hasCompletedOnboarding` is read by @AppStorage from the argument domain, so it never
    /// touches the persisted value.
    /// `resetProgress` passes `-resetProgress YES` (Debug builds): saved progress and the onboarding
    /// flag are cleared before the app reads them, so every test starts from an empty pile and no
    /// reviewed items without clicking through Settings. Photos itself is never touched.
    func launch(onboardingDone: Bool = true, resetProgress: Bool = false) {
        app.launchArguments = [
            "-hasCompletedOnboarding", onboardingDone ? "YES" : "NO",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ] + (resetProgress ? ["-resetProgress", "YES"] : [])
        app.launch()
    }

    /// Taps "Allow Full Access" on the system alert if one is showing. Returns whether it did.
    @discardableResult
    func allowFullAccessIfPrompted(timeout: TimeInterval = 6) -> Bool {
        let button = springboard.alerts.buttons["Allow Full Access"]
        guard button.waitForExistence(timeout: timeout) else { return false }
        button.tap()
        return true
    }

    /// Launches past onboarding with a clean slate (`-resetProgress YES`), grants access when asked,
    /// and waits for the swipe screen.
    func launchReady() {
        launch(resetProgress: true)
        grantAccessThroughApp()
        XCTAssertTrue(counter.waitForExistence(timeout: 20), "Swipe screen never appeared.\n\(app.debugDescription)")
        XCTAssertEqual(pileCount, 0, "-resetProgress should leave an empty pile")
    }

    /// Gets from a fresh launch to the swipe screen whatever the Photos grant state is: already
    /// granted (nothing to do), not asked yet (permission screen, then the system alert).
    func grantAccessThroughApp() {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if counter.exists { return }
            if allowFullAccessIfPrompted(timeout: 0.5) { return }
            let allow = app.buttons["Allow photo access"]
            if allow.exists { allow.tap(); allowFullAccessIfPrompted(timeout: 6); return }
            usleep(300_000)
        }
    }

    // MARK: Elements

    /// Located by accessibility identifier; the label is still read for the numbers.
    var counter: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "swipe.counter").firstMatch
    }

    var card: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "swipe.card").firstMatch
    }

    var trashPill: XCUIElement {
        app.buttons.matching(identifier: "swipe.trashPill").firstMatch
    }

    func button(_ label: String) -> XCUIElement { app.buttons[label] }

    /// Items left to review, from the counter's accessibility label ("17 items left to review").
    var remaining: Int {
        Self.leadingInt(counter.label)
    }

    /// Items in the pile, from the trash pill label ("Trash pile, 3 items, 4.2 MB. Opens review.").
    var pileCount: Int {
        let label = trashPill.label
        guard label.hasPrefix("Trash pile") else { return 0 }
        return Self.firstInt(in: label)
    }

    static func leadingInt(_ s: String) -> Int {
        Int(s.prefix { $0.isNumber }) ?? -1
    }

    static func firstInt(in s: String) -> Int {
        let digits = s.drop { !$0.isNumber }.prefix { $0.isNumber }
        return Int(digits) ?? -1
    }

    // MARK: Actions

    /// Waits for the counter to show `n`.
    func waitForRemaining(_ n: Int, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate { _, _ in self.counter.exists && self.remaining == n }
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter().wait(for: [exp], timeout: timeout)
        XCTAssertEqual(result, .completed, "Counter should read \(n) but reads \(counter.exists ? counter.label : "<missing>")", file: file, line: line)
    }

    func waitForPile(_ n: Int, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate { _, _ in self.pileCount == n }
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter().wait(for: [exp], timeout: timeout)
        XCTAssertEqual(result, .completed, "Pile should hold \(n) but holds \(pileCount)", file: file, line: line)
    }

    enum Direction { case left, right, up }

    /// A real touch drag across the card, long and fast enough to commit the decision.
    func swipeCard(_ direction: Direction) {
        let card = self.card
        XCTAssertTrue(card.waitForExistence(timeout: 8), "No card on screen")
        let settled = NSPredicate { _, _ in self.card.exists && self.card.isHittable && !self.app.navigationBars.firstMatch.exists }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 5), .completed, "Card never became hittable")
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end: XCUICoordinate
        switch direction {
        case .left: end = card.coordinate(withNormalizedOffset: CGVector(dx: -0.4, dy: 0.5))
        case .right: end = card.coordinate(withNormalizedOffset: CGVector(dx: 1.4, dy: 0.5))
        case .up: end = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -0.3))
        }
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
    }

    func openTrash() {
        let pill = trashPill
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.tap()
        XCTAssertTrue(app.navigationBars["Trash pile"].waitForExistence(timeout: 5), "Trash sheet did not open")
    }

    func closeTrash() {
        app.navigationBars["Trash pile"].buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Trash pile"].waitForNonExistence(timeout: 5))
    }

    /// Photo cells inside the trash sheet.
    var trashCells: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Photo,' OR label BEGINSWITH 'Video,'"))
    }

    /// Finds the real iOS delete confirmation's button ("Delete N Photos"). It is hosted outside the
    /// app, so it is looked up on springboard first and in the app as a fallback.
    func systemDeleteButton(timeout: TimeInterval = 10) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        let isDelete = NSPredicate(format: "label BEGINSWITH 'Delete'")
        repeat {
            for host in [springboard, app] {
                let button = host.alerts.buttons.matching(isDelete).firstMatch
                if button.exists { return button }
                let sheetButton = host.sheets.buttons.matching(isDelete).firstMatch
                if sheetButton.exists { return sheetButton }
            }
            usleep(200_000)
        } while Date() < deadline
        return nil
    }

    /// Accepts the real iOS delete confirmation.
    @discardableResult
    func confirmSystemDelete(timeout: TimeInterval = 10) -> Bool {
        guard let button = systemDeleteButton(timeout: timeout) else { return false }
        button.tap()
        return true
    }

    /// Declines the system delete confirmation ("Allow Byegones to delete 2 photos?" > "Don't Allow").
    @discardableResult
    func cancelSystemDelete(timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for host in [springboard, app] {
                let button = host.descendants(matching: .button).matching(NSPredicate(format: "label IN {'Don’t Allow', 'Don\\'t Allow', 'Cancel'}")).firstMatch
                if button.exists, button.isHittable { button.tap(); return true }
            }
            usleep(200_000)
        } while Date() < deadline
        let dump = XCTAttachment(string: "springboard:\n\(springboard.debugDescription)\napp:\n\(app.debugDescription)")
        dump.lifetime = .keepAlways
        add(dump)
        return false
    }

    /// Sends the app to the background (flushes progress, like a real user would) and relaunches it.
    func relaunch() {
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.terminate()
        launch()
        XCTAssertTrue(counter.waitForExistence(timeout: 20), "Swipe screen did not come back after relaunch")
    }

    /// Needs `n` photos in the queue; fails with the fix instead of a confusing downstream error.
    func requireRemaining(atLeast n: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(remaining, n, "Not enough photos in the simulator. Run scripts/seed-uitest-photos.sh <udid>.", file: file, line: line)
    }
}
