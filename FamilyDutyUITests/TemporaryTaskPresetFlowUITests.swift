import XCTest

final class TemporaryTaskPresetFlowUITests: XCTestCase {
    func testSelectingPresetFillsTemporaryTaskName() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedMember"]
        app.launch()

        app.buttons["dashboard-add-temporary"].tap()

        let picker = app.descendants(matching: .any)["temporary-task-preset-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        picker.tap()

        let sweepPreset = app.descendants(matching: .any)["temporary-task-preset-扫地"]
        XCTAssertTrue(sweepPreset.waitForExistence(timeout: 3))
        sweepPreset.tap()

        let titleField = app.textFields["任务名称"]
        XCTAssertEqual(titleField.value as? String, "扫地")
    }
}
