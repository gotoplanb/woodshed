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
        let okButton = springboard.buttons["OK"]
        if okButton.waitForExistence(timeout: 2) {
            okButton.tap()
            sleep(1)
        }
    }

    func testBothSetlistsExist() throws {
        screenshot("Library")

        let appetite = app.staticTexts["Appetite for Destruction"]
        let testPlayback = app.staticTexts["Playback Test"]

        let appetiteExists = appetite.waitForExistence(timeout: 5)
        let testPlaybackExists = testPlayback.waitForExistence(timeout: 3)

        print("TEST: Appetite exists = \(appetiteExists)")
        print("TEST: Playback Test exists = \(testPlaybackExists)")

        // List all visible text
        for text in app.staticTexts.allElementsBoundByIndex.prefix(20) {
            print("TEST: StaticText = '\(text.label)'")
        }

        XCTAssertTrue(appetiteExists, "Should see Appetite for Destruction")
        XCTAssertTrue(testPlaybackExists, "Should see Playback Test")
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
        XCTAssertTrue(app.staticTexts["Intro"].waitForExistence(timeout: 3))
    }

    func testPracticeModeNavigation() throws {
        let setlistCell = app.staticTexts["Playback Test"]
        guard setlistCell.waitForExistence(timeout: 5) else {
            // Fall back to appetite if test playback doesn't exist
            let appetite = app.staticTexts["Appetite for Destruction"]
            guard appetite.waitForExistence(timeout: 3) else {
                screenshot("FAIL-NoSetlists")
                XCTFail("No setlists found")
                return
            }
            appetite.tap()
            sleep(1)
            screenshot("FAIL-NoTestPlayback-UsingAppetite")
            XCTFail("Playback Test setlist not found")
            return
        }
        setlistCell.tap()
        sleep(1)
        screenshot("TestPlayback-Detail")

        let playAll = app.buttons["Play All"]
        guard playAll.waitForExistence(timeout: 3) else {
            screenshot("FAIL-NoPlayAll")
            XCTFail("Play All not found")
            return
        }

        playAll.tap()
        sleep(5)
        printState("5s")
        sleep(10)
        printState("15s")
        sleep(15)
        printState("30s-should-advance")
        sleep(5)
        printState("35s-should-be-michelle")

        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 5) {
            doneButton.tap()
            sleep(1)
            screenshot("AfterDone")
        } else {
            screenshot("FAIL-NoDone")
            XCTFail("Done button not found")
        }
    }

    private func printState(_ label: String) {
        var texts: [String] = []
        for text in app.staticTexts.allElementsBoundByIndex.prefix(12) {
            texts.append(text.label)
        }
        print("TEST-\(label): \(texts)")
        screenshot(label)
    }

    private func screenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
