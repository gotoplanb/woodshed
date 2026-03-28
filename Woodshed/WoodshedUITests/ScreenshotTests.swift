import XCTest

final class ScreenshotTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.terminate()
        app.launch()

        // Handle permissions
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
            sleep(1)
        }
        let okButton = springboard.buttons["OK"]
        if okButton.waitForExistence(timeout: 2) {
            okButton.tap()
            sleep(1)
        }
    }

    func testCaptureScreenshots() throws {
        // 1. About screen (shows on first launch)
        sleep(2)
        screenshot("01-about")

        // Dismiss About
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 3) {
            getStarted.tap()
            sleep(1)
        }

        // 2. Setlist Library
        screenshot("02-setlist-library")

        // 3. Tap into setlist to see songs
        let appetite = app.staticTexts["Appetite for Destruction"]
        guard appetite.waitForExistence(timeout: 5) else { return }
        appetite.tap()
        sleep(1)
        screenshot("03-setlist-songs")

        // 4. Tap a song to see practice mode
        let brownstone = app.staticTexts["Mr. Brownstone"]
        guard brownstone.waitForExistence(timeout: 3) else { return }
        brownstone.tap()
        sleep(5) // Wait for playback to start
        screenshot("04-practice-mode")

        // 5. Tap loop to show it active
        let loopButton = app.buttons["repeat"]
        if loopButton.waitForExistence(timeout: 2) {
            loopButton.tap()
            sleep(1)
            screenshot("05-practice-loop")
        }
    }

    private func screenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
