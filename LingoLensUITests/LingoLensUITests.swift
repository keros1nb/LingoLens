import XCTest

@MainActor
final class LingoLensUITests: XCTestCase {
    private func launch(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        return app
    }

    func testCaptureSelectTranslateSaveAndOpenDictionary() {
        let app = launch()
        screenshot("Camera", app: app)
        app.buttons["capturePhoto"].tap()
        XCTAssertTrue(app.staticTexts["russianTranslation"].waitForExistence(timeout: 5))
        screenshot("Result", app: app)
        app.buttons["candidate-chair"].tap()
        XCTAssertTrue(app.staticTexts["стул"].waitForExistence(timeout: 5))
        let save = app.buttons["saveWord"]
        app.swipeUp()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.buttons["Готово"].waitForExistence(timeout: 5))
        app.buttons["Готово"].tap()
        app.buttons["Закрыть"].tap()
        app.tabBars.buttons["Мой словарь"].tap()
        let word = app.buttons["word-chair"]
        XCTAssertTrue(word.waitForExistence(timeout: 5))
        screenshot("Dictionary", app: app)
        word.tap()
        XCTAssertTrue(app.staticTexts["стул"].waitForExistence(timeout: 5))
    }

    private func screenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRecognitionFailureAllowsRetake() {
        let app = launch(arguments: ["--recognition-error"])
        app.buttons["capturePhoto"].tap()
        XCTAssertTrue(app.staticTexts["recognitionError"].waitForExistence(timeout: 5))
        app.buttons["retakePhoto"].tap()
        XCTAssertTrue(app.buttons["capturePhoto"].waitForExistence(timeout: 5))
    }

    func testTranslationFailureKeepsEnglishAndDisablesSaving() {
        let app = launch(arguments: ["--translation-error"])
        app.buttons["capturePhoto"].tap()
        XCTAssertTrue(app.staticTexts["translationError"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["selectedWord"].label, "cup")
        app.swipeUp()
        XCTAssertFalse(app.buttons["saveWord"].isEnabled)
        XCTAssertTrue(app.buttons["Повторить перевод"].exists)
    }

    func testDarkModeWithLargeTextAllowsCaptureAndRetake() {
        let app = launch(arguments: ["--dark-mode",
                                     "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let capture = app.buttons["capturePhoto"]
        for _ in 0..<4 {
            if capture.isHittable { break }
            app.swipeUp()
        }
        screenshot("Camera-Dark-LargeText", app: app)
        XCTAssertTrue(capture.isHittable)
        capture.tap()
        XCTAssertTrue(app.staticTexts["russianTranslation"].waitForExistence(timeout: 5))
        let retake = app.buttons["retakePhoto"]
        for _ in 0..<4 {
            if retake.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(retake.isHittable)
        retake.tap()
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
    }
}
