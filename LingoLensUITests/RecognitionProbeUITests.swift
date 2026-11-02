import XCTest

@MainActor
final class RecognitionProbeUITests: XCTestCase {
    func testDiagnosticScreenOpensPhotoPicker() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let choosePhoto = app.buttons["chooseDiagnosticPhoto"]
        XCTAssertTrue(choosePhoto.waitForExistence(timeout: 5))
        XCTAssertTrue(choosePhoto.isEnabled)
        choosePhoto.tap()
        let cancel = app.buttons["Cancel"]
        guard cancel.waitForExistence(timeout: 15) else {
            print(app.debugDescription)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            XCTFail("The system photo picker should offer a cancel button")
            return
        }
        cancel.tap()
        XCTAssertTrue(choosePhoto.isHittable)
    }
}
