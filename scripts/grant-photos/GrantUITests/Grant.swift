import XCTest
final class Grant: XCTestCase {
    func testAllow() {
        let app = XCUIApplication(bundleIdentifier: ProcessInfo.processInfo.environment["BUNDLE_ID"] ?? "com.example.photocleaner")
        app.launchArguments = ["-screenshotMode", "YES", "-screenshotScene", "swipe"]
        app.launch()
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = sb.buttons["Allow Full Access"]
        if allow.waitForExistence(timeout: 10) { allow.tap() }
        sleep(2)
        app.terminate()
    }
}
