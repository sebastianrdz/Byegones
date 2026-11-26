import XCTest

@MainActor
final class OnboardingAndPermissionUITests: ByegonesUITestCase {
    /// Forgets the Photos grant so the system prompt shows again. Terminates the app.
    private func resetPhotoAuthorization() {
        app.resetAuthorizationStatus(for: .photos)
    }

    func testOnboardingWalksThreePagesThenAsksForPermissionAndShowsTheSwipeScreen() {
        resetPhotoAuthorization()
        launch(onboardingDone: false)

        XCTAssertTrue(app.staticTexts["Swipe your way clean"].waitForExistence(timeout: 10))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Your photos never leave your iPhone"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Let's find your photos"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Next"].exists, "Page 3 offers the permission CTA, not Next")

        app.buttons["Allow photo access"].tap()
        XCTAssertTrue(allowFullAccessIfPrompted(), "The system photo prompt never appeared")
        XCTAssertTrue(counter.waitForExistence(timeout: 20), "Swipe screen should follow a granted permission")
        XCTAssertTrue(card.exists)
        XCTAssertGreaterThan(remaining, 0)
    }

    func testNotNowOnLastPageLandsOnAPermissionScreenThatCanStillGrantAccess() {
        resetPhotoAuthorization()
        launch(onboardingDone: false)
        app.buttons["Next"].tap()
        app.buttons["Next"].tap()
        XCTAssertTrue(app.buttons["Not now"].waitForExistence(timeout: 5))
        app.buttons["Not now"].tap()

        // Onboarding is over but nothing is granted: the pre-permission screen takes over.
        XCTAssertTrue(app.staticTexts["Let's find your photos"].waitForExistence(timeout: 5))
        XCTAssertFalse(counter.exists)
        app.buttons["Allow photo access"].tap()
        XCTAssertTrue(allowFullAccessIfPrompted(), "The system photo prompt never appeared")
        XCTAssertTrue(counter.waitForExistence(timeout: 20))
    }

    func testDenyingAccessShowsPhotoAccessIsOffWithOpenSettings() {
        resetPhotoAuthorization()
        launch(onboardingDone: false)
        app.buttons["Next"].tap()
        app.buttons["Next"].tap()
        app.buttons["Allow photo access"].tap()
        let deny = springboard.alerts.buttons["Don’t Allow"]
        let denyStraight = springboard.alerts.buttons["Don't Allow"]
        XCTAssertTrue(deny.waitForExistence(timeout: 6) || denyStraight.exists, "No system prompt")
        (deny.exists ? deny : denyStraight).tap()

        XCTAssertTrue(app.staticTexts["Photo access is off"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        XCTAssertFalse(counter.exists)

        // Leave the simulator the way the other tests expect it.
        resetPhotoAuthorization()
        launch()
        grantAccessThroughApp()
        XCTAssertTrue(counter.waitForExistence(timeout: 20))
    }

    func testReturningUserSkipsOnboardingAndGoesStraightToTheSwipeScreen() {
        launch(onboardingDone: true)
        grantAccessThroughApp()
        XCTAssertTrue(counter.waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["Swipe your way clean"].exists)
    }
}
