import XCTest

final class InteractionTests: XCTestCase {
    func testWheelEditingAndReminderAccess() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let healthLabel = app.buttons["wheel-area-health"]
        XCTAssertTrue(healthLabel.waitForExistence(timeout: 10))
        screenshot("Empty wheel")
        healthLabel.tap()
        let slider = app.sliders["score-slider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.7)
        let note = app.textViews["area-note"]
        note.tap()
        note.typeText("A quiet walk.")
        app.navigationBars.buttons["Done"].tap()

        let handle = app.descendants(matching: .any).matching(identifier: "wheel-handle-health").firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertEqual(handle.value as? String, "7 out of 10")
        // Use real screen coordinates so this exercises the gesture, not just its score formula.
        let radar = app.descendants(matching: .any).matching(identifier: "life-wheel").firstMatch
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: -radar.frame.width * 113 / 360 * 0.3))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertEqual(handle.value as? String, "10 out of 10")
        screenshot("Edited wheel")

        app.buttons["reminder-shortcut"].tap()
        let toggle = app.switches["reminder-enabled"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(app.buttons["reminder-frequency"].exists)
        screenshot("Reminder controls")
        app.buttons["save-reminder"].tap()
        let permission = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        if permission.waitForExistence(timeout: 5) { permission.tap() }
        XCTAssertTrue(app.buttons["reminder-shortcut"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["reminder-shortcut"].value as? String, "On")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["reminder-shortcut"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["reminder-shortcut"].value as? String, "On")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "wheel-handle-health").firstMatch.value as? String, "10 out of 10")
        app.buttons["wheel-area-health"].tap()
        XCTAssertEqual(app.textViews["area-note"].value as? String, "A quiet walk.")
        app.navigationBars.buttons["Done"].tap()

        app.buttons["settings"].tap()
        app.buttons["reminder-settings"].tap()
        XCTAssertTrue(app.staticTexts["Next scheduled reminder"].waitForExistence(timeout: 5))
        app.switches["reminder-enabled"].tap()
        app.buttons["save-reminder"].tap()
        XCTAssertTrue(app.buttons["reminder-shortcut"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["reminder-shortcut"].value as? String, "Off")

        app.buttons["tab-notes"].tap()
        XCTAssertTrue(app.staticTexts["A quiet walk."].exists)
        app.buttons["tab-history"].tap()
        XCTAssertTrue(app.staticTexts["Every moment counts."].exists)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
