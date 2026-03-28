import XCTest

final class PlaybackFlowTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.terminate()
        app.launch()

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
        let appetite = app.staticTexts["Appetite for Destruction"]
        let testPlayback = app.staticTexts["Playback Test"]

        let appetiteExists = appetite.waitForExistence(timeout: 5)
        let testPlaybackExists = testPlayback.waitForExistence(timeout: 3)

        print("TEST: Appetite exists = \(appetiteExists)")
        print("TEST: Playback Test exists = \(testPlaybackExists)")

        for text in app.staticTexts.allElementsBoundByIndex.prefix(20) {
            print("TEST: StaticText = '\(text.label)'")
        }

        XCTAssertTrue(appetiteExists, "Should see Appetite for Destruction")
        XCTAssertTrue(testPlaybackExists, "Should see Playback Test")
    }

    func testSetlistShowsSongs() throws {
        let setlistCell = app.staticTexts["Playback Test"]
        guard setlistCell.waitForExistence(timeout: 5) else {
            XCTFail("Playback Test not found")
            return
        }
        setlistCell.tap()
        sleep(1)

        // Should see songs, not sections
        let brownstone = app.staticTexts["Mr. Brownstone"]
        let michelle = app.staticTexts["My Michelle"]
        XCTAssertTrue(brownstone.waitForExistence(timeout: 3), "Should see Mr. Brownstone")
        XCTAssertTrue(michelle.waitForExistence(timeout: 3), "Should see My Michelle")

        printState("SetlistSongs")
    }

    func testJamMode() throws {
        let setlistCell = app.staticTexts["Playback Test"]
        guard setlistCell.waitForExistence(timeout: 5) else { return }
        setlistCell.tap()
        sleep(1)

        let jamButton = app.buttons["Jam"]
        guard jamButton.waitForExistence(timeout: 3) else {
            XCTFail("Jam button not found")
            return
        }
        jamButton.tap()
        sleep(5)
        printState("JamMode-5s")

        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        }
    }

    func testPracticeMode() throws {
        let setlistCell = app.staticTexts["Playback Test"]
        guard setlistCell.waitForExistence(timeout: 5) else { return }
        setlistCell.tap()
        sleep(1)

        // Tap a song to enter practice mode
        let brownstone = app.staticTexts["Mr. Brownstone"]
        guard brownstone.waitForExistence(timeout: 3) else {
            XCTFail("Mr. Brownstone not found")
            return
        }
        brownstone.tap()
        sleep(5)
        printState("PracticeMode-5s")

        // Should see section list
        let intro = app.staticTexts["Intro"]
        XCTAssertTrue(intro.waitForExistence(timeout: 3), "Should see Intro section")
    }

    func testLoopInPracticeMode() throws {
        let setlistCell = app.staticTexts["Playback Test"]
        guard setlistCell.waitForExistence(timeout: 5) else { return }
        setlistCell.tap()
        sleep(1)

        let brownstone = app.staticTexts["Mr. Brownstone"]
        guard brownstone.waitForExistence(timeout: 3) else { return }
        brownstone.tap()
        sleep(3)

        // Tap loop button — try multiple label patterns
        var tappedLoop = false
        for label in ["repeat", "Repeat", "repeat.1", "Repeat 1"] {
            let btn = app.buttons[label]
            if btn.waitForExistence(timeout: 1) {
                btn.tap()
                print("TEST: Tapped loop button with label '\(label)'")
                tappedLoop = true
                break
            }
        }
        if !tappedLoop {
            // Dump all buttons for debugging
            for btn in app.buttons.allElementsBoundByIndex.prefix(15) {
                print("TEST-BTN: '\(btn.label)' id='\(btn.identifier)'")
            }
            XCTFail("Could not find loop button")
            return
        }

        // Wait past the Intro endTime (18s) — at 25s we should still be on Intro if looping
        sleep(20)
        printState("Loop-23s")

        sleep(5)
        printState("Loop-28s")
    }

    private func printState(_ label: String) {
        var texts: [String] = []
        for text in app.staticTexts.allElementsBoundByIndex.prefix(15) {
            texts.append(text.label)
        }
        print("TEST-\(label): \(texts)")
    }
}
