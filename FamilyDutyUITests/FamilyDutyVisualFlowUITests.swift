import XCTest

final class FamilyDutyVisualFlowUITests: XCTestCase {
    func testDashboardExposesProgressHeaderAndSemanticTaskCards() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedDashboardTask"]
        app.launch()

        XCTAssertTrue(app.otherElements["dashboard-progress-card"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'dashboard-task-' AND label CONTAINS '扫地'" )).firstMatch.exists)
    }

    func testTaskBoardExposesTodaySummaryCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedTaskBoard"]
        app.launch()

        app.buttons["任务面板"].tap()

        XCTAssertTrue(app.otherElements["task-board-summary"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'task-board-task-' AND label CONTAINS '面板待处理'" )).firstMatch.exists)
    }
}
