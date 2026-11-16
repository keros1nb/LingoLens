import XCTest

@MainActor
final class DeviceValidationUITests: XCTestCase {
    func testCaptureAndDictionaryRemainResponsive() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires physical camera.")
        #else
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        assertCameraPreviewing(app)
        let dictionaryStart = ContinuousClock.now
        app.tabBars.buttons["Мой словарь"].tap()
        let dictionaryTime = seconds(dictionaryStart.duration(to: .now))
        print("[CameraResponsiveness] Dictionary: \(dictionaryTime)s")
        XCTAssertLessThan(dictionaryTime, 3,
                          "Leaving the preview must not block the main thread.")
        let cameraStart = ContinuousClock.now
        app.tabBars.buttons["Камера"].tap()
        let cameraTime = seconds(cameraStart.duration(to: .now))
        print("[CameraResponsiveness] Camera: \(cameraTime)s")
        XCTAssertLessThan(cameraTime, 3,
                          "Returning to the camera must not rebuild a blocked preview connection.")
        assertCameraPreviewing(app)
        let captureStart = ContinuousClock.now
        app.buttons["capturePhoto"].tap()
        XCTAssertTrue(app.images["capturedPhoto"].waitForExistence(timeout: 10))
        let captureTime = seconds(captureStart.duration(to: .now))
        print("[CameraResponsiveness] Capture result: \(captureTime)s")
        XCTAssertLessThan(captureTime, 6,
                          "The result must appear without waiting for a blocked preview detachment.")
        let retakeStart = ContinuousClock.now
        app.buttons["Закрыть"].tap()
        let retakeTime = seconds(retakeStart.duration(to: .now))
        print("[CameraResponsiveness] Retake: \(retakeTime)s")
        XCTAssertLessThan(retakeTime, 3)
        assertCameraPreviewing(app)
        #endif
    }

    func testCameraRestartsAfterDictionaryTab() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("The camera regression requires a physical iPhone.")
        #else
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        addUIInterruptionMonitor(withDescription: "Camera access") { alert in
            for title in ["Разрешить", "Allow", "OK", "ОК"] {
                if alert.buttons[title].exists { alert.buttons[title].tap(); return true }
            }
            return false
        }
        if app.buttons["allowCamera"].waitForExistence(timeout: 3) {
            app.buttons["allowCamera"].tap()
            app.tap()
        }
        assertCameraPreviewing(app)
        for _ in 0..<3 {
            app.tabBars.buttons["Мой словарь"].tap()
            app.tabBars.buttons["Камера"].tap()
            assertCameraPreviewing(app)
        }
        app.buttons["capturePhoto"].tap()
        XCTAssertTrue(app.images["capturedPhoto"].waitForExistence(timeout: 10))
        app.buttons["Закрыть"].tap()
        assertCameraPreviewing(app)
        XCUIDevice.shared.press(.home)
        app.activate()
        assertCameraPreviewing(app)
        #endif
    }

    #if !targetEnvironment(simulator)
    private func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    private func assertCameraPreviewing(_ app: XCUIApplication) {
        let preview = app.descendants(matching: .any)["cameraPreview"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        let frames = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Камера включена"), object: preview)
        XCTAssertEqual(XCTWaiter.wait(for: [frames], timeout: 10), .completed,
                       "The preview layer must actually render camera frames.")
    }
    #endif

    func testNativeTranslationAndSavingOnIPhone() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Apple Translation requires a physical iPhone.")
        #else
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--native-translation"]
        app.launch()
        app.buttons["capturePhoto"].tap()
        let translation = app.staticTexts["russianTranslation"]
        if !translation.waitForExistence(timeout: 15) {
            let error = app.staticTexts["translationError"]
            if error.exists {
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.lifetime = .keepAlways
                add(screenshot)
                XCTFail("Native translation error: \(error.value ?? error.label)")
                return
            }
            XCTAssertTrue(translation.waitForExistence(timeout: 105), "Complete the system language download prompt on the iPhone if shown.")
        }
        XCTAssertFalse(translation.label.isEmpty)
        XCTAssertNotEqual(translation.label, "cup")
        app.swipeUp()
        app.buttons["speakWord"].tap()
        XCTAssertFalse(app.alerts["Озвучка недоступна"].exists)
        app.buttons["saveWord"].tap()
        XCTAssertTrue(app.buttons["Готово"].waitForExistence(timeout: 5))
        app.buttons["Готово"].tap()
        app.buttons["Закрыть"].tap()
        app.tabBars.buttons["Мой словарь"].tap()
        XCTAssertTrue(app.buttons["word-cup"].waitForExistence(timeout: 5))
        #endif
    }
}
