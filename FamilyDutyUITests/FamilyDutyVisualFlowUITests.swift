import XCTest

final class FamilyDutyVisualFlowUITests: XCTestCase {
    func testDashboardExposesProgressHeaderAndSemanticTaskCards() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedDashboardTask"]
        app.launch()

        XCTAssertTrue(app.otherElements["dashboard-progress-card"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["dashboard-task-扫地"].exists)
    }

    func testTaskBoardExposesTodaySummaryCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedTaskBoard"]
        app.launch()

        app.buttons["任务面板"].tap()

        XCTAssertTrue(app.otherElements["task-board-summary"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["task-board-task-面板待处理"].exists)
    }
}
