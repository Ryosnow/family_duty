import XCTest

final class DashboardFlowUITests: XCTestCase {
    func testCompletingTaskMovesItToRecentHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedDashboardTask"]
        app.launch()

        let task = app.buttons["dashboard-task-扫地"]
        XCTAssertTrue(task.waitForExistence(timeout: 3))
        task.tap()

        let completeButton = app.buttons["确认完成"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 2))
        completeButton.tap()

        XCTAssertFalse(task.waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["history-扫地-by-小明"].waitForExistence(timeout: 2))
    }
}
