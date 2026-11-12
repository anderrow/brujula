import XCTest

final class InteractionTests: XCTestCase {
    func testWheelEditingAndReminderAccess() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let healthLabel = app.buttons["wheel-area-health"]
        XCTAssertTrue(healthLabel.waitForExistence(timeout: 10))
        let untouched = app.buttons["wheel-area-work"]
        untouched.tap()
        let untouchedNote = app.textViews["area-note"]
        XCTAssertTrue(untouchedNote.exists)
        XCTAssertEqual(app.staticTexts["editor-score"].label, "—")
        XCTAssertTrue((untouchedNote.value as? String ?? "").isEmpty)
        app.buttons["editor-toolbar-done"].tap()
        XCTAssertTrue(untouched.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(untouched.waitForExistence(timeout: 10))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "wheel-handle-work").firstMatch.value as? String, "Not rated")
        untouched.tap()
        XCTAssertTrue(untouchedNote.exists)
        XCTAssertEqual(app.staticTexts["editor-score"].label, "—")
        XCTAssertTrue((untouchedNote.value as? String ?? "").isEmpty)
        app.buttons["editor-toolbar-done"].tap()
        XCTAssertTrue(healthLabel.waitForExistence(timeout: 5))
        screenshot("Empty wheel")
        healthLabel.tap()
        let slider = app.sliders["score-slider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.7)
        XCTAssertTrue(app.staticTexts["reflection-prompt-actions"].exists)
        XCTAssertTrue(app.staticTexts["reflection-prompt-possibilities"].exists)
        XCTAssertTrue(app.staticTexts["reflection-prompt-next-step"].exists)
        let note = app.textViews["area-note"]
        for _ in 0..<6 {
            if note.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(note.isHittable)
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
        // Scroll in the page margin so the swipe cannot drag a wheel handle.
        let scroll = app.scrollViews.firstMatch
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.8))
            .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.25)))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "wheel-handle-friends").firstMatch.value as? String, "Not rated")
        screenshot("Area icons")

        app.buttons["reminder-shortcut"].tap()
        let toggle = app.switches["reminder-enabled"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        // SwiftUI exposes the full row as a switch; its midpoint can be empty space.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        waitForValue("1", of: toggle)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "reminder-frequency").firstMatch.waitForExistence(timeout: 5))
        screenshot("Reminder controls")
        app.buttons["save-reminder"].tap()
        let permission = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        if permission.waitForExistence(timeout: 5) { permission.tap() }
        XCTAssertTrue(app.buttons["reminder-shortcut"].waitForExistence(timeout: 10))
        waitForValue("On", of: app.buttons["reminder-shortcut"])

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["reminder-shortcut"].waitForExistence(timeout: 10))
        waitForValue("On", of: app.buttons["reminder-shortcut"])
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "wheel-handle-health").firstMatch.value as? String, "10 out of 10")
        app.buttons["wheel-area-health"].tap()
        XCTAssertEqual(app.textViews["area-note"].value as? String, "A quiet walk.")
        app.navigationBars.buttons["Done"].tap()

        app.buttons["settings"].tap()
        app.buttons["reminder-settings"].tap()
        screenshot("Saved reminder")
        XCTAssertTrue(app.staticTexts["reminder-next-date"].waitForExistence(timeout: 5))
        app.switches["reminder-enabled"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        waitForValue("0", of: app.switches["reminder-enabled"])
        app.buttons["save-reminder"].tap()
        XCTAssertTrue(app.buttons["reminder-shortcut"].waitForExistence(timeout: 10))
        waitForValue("Off", of: app.buttons["reminder-shortcut"])

        app.buttons["tab-notes"].tap()
        XCTAssertTrue((app.buttons["note-health"].value as? String)?.contains("A quiet walk.") == true)
        app.buttons["tab-history"].tap()
        XCTAssertTrue(app.staticTexts["Every moment counts."].exists)

        app.buttons["settings"].tap()
        app.buttons["language-es"].tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["language-es"].isSelected)
        screenshot("Spanish language settings")
        app.buttons["settings-done"].tap()
        app.buttons["tab-wheel"].tap()
        XCTAssertTrue(app.buttons["wheel-area-health"].label.contains("Salud"))
        XCTAssertTrue(app.staticTexts["wheel-heading"].label.contains("Tu vida"))
        app.buttons["wheel-area-health"].tap()
        XCTAssertEqual(app.textViews["area-note"].value as? String, "A quiet walk.")
        app.buttons["editor-toolbar-done"].tap()
        screenshot("Spanish wheel")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["wheel-area-health"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["wheel-area-health"].label.contains("Salud"))
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["language-es"].isSelected)
        app.buttons["language-en"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["language-en"].isSelected)
        app.buttons["settings-done"].tap()
        XCTAssertTrue(app.buttons["wheel-area-health"].label.contains("Health"))
        screenshot("English restored")
    }

    func testAccessibilityTextKeepsEditingReachable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["settings"].isHittable)
        let health = app.buttons["area-health"]
        for _ in 0..<8 {
            if health.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(health.isHittable)
        health.tap()
        let slider = app.sliders["score-slider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.5)
        let nextStep = app.staticTexts["reflection-prompt-next-step"]
        for _ in 0..<8 {
            if nextStep.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(nextStep.isHittable)
        let note = app.textViews["area-note"]
        for _ in 0..<6 {
            if note.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(note.isHittable)
        screenshot("Largest accessibility text")
        app.buttons["editor-toolbar-done"].tap()
        app.terminate()
    }

    override func tearDownWithError() throws {
        screenshot("End of interaction check")
        let tree = XCTAttachment(string: XCUIApplication().debugDescription)
        tree.name = "Accessibility tree"
        tree.lifetime = .keepAlways
        add(tree)
        try super.tearDownWithError()
    }

    private func waitForValue(_ value: String, of element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
