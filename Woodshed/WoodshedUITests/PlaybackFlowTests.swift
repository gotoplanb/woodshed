import XCTest

final class PlaybackFlowTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.terminate()
        app.launch()

        // Handle MusicKit permission dialog if it appears
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
            sleep(1)
        }

        // Also handle media library permission if it appears
        let okButton = springboard.buttons["OK"]
        if okButton.waitForExistence(timeout: 2) {
            okButton.tap()
            sleep(1)
        }
    }

    func testSetlistDetailShows() throws {
        let setlistCell = app.staticTexts["Appetite for Destruction"]
        guard setlistCell.waitForExistence(timeout: 5) else {
            screenshot("FAIL-NoSetlist")
            XCTFail("Setlist not found")
            return
        }
        setlistCell.tap()
        sleep(1)

        screenshot("SetlistDetail")

        // Verify sections exist
        XCTAssertTrue(app.staticTexts["Intro"].waitForExistence(timeout: 3))
    }

    func testPracticeModeNavigation() throws {
        // Navigate to setlist
        let setlistCell = app.staticTexts["Appetite for Destruction"]
        guard setlistCell.waitForExistence(timeout: 5) else { return }
        setlistCell.tap()
        sleep(1)

        // Tap Play All
        let playAll = app.buttons["Play All"]
        guard playAll.waitForExistence(timeout: 3) else {
            screenshot("FAIL-NoPlayAll")
            XCTFail("Play All not found")
            return
        }

        screenshot("BeforePlayAll")
        playAll.tap()
        sleep(2)
        screenshot("AfterPlayAll-2s")
        sleep(5)
        screenshot("AfterPlayAll-7s")

        // Try to find Done button
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 5) {
            screenshot("PracticeMode-WithDone")
            doneButton.tap()
            sleep(1)
            screenshot("AfterDone")
        } else {
            screenshot("FAIL-NoDoneButton")
            // Print what's on screen
            print("TEST: Current screen elements:")
            for button in app.buttons.allElementsBoundByIndex {
                print("  Button: '\(button.label)'")
            }
            for text in app.staticTexts.allElementsBoundByIndex.prefix(10) {
                print("  Text: '\(text.label)'")
            }
            XCTFail("Practice mode did not load (no Done button)")
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
