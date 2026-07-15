import XCTest

final class DashboardFlowUITests: XCTestCase {
    func testCompletingTaskMovesItToRecentHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedDashboardTask"]
        app.launch()

        let task = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'dashboard-task-' AND label CONTAINS '扫地'" )).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 3))
        task.tap()

        let completeButton = app.buttons["确认完成"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 2))
        completeButton.tap()

        XCTAssertFalse(task.waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'history-' AND label CONTAINS '小明'" )).firstMatch.waitForExistence(timeout: 2))
    }

    func testOverdueTaskAppearsInOverdueSectionWithIndicator() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedOverdueTask"]
        app.launch()

        XCTAssertTrue(app.staticTexts["已逾期"].waitForExistence(timeout: 3))
        let task = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'dashboard-task-' AND label CONTAINS '逾期任务'" )).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 2))
        XCTAssertTrue(task.label.contains("已逾期"))
    }

    func testQuickCompletionRequiresConfirmationBeforeRemovingTask() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedDashboardTask"]
        app.launch()

        let quickComplete = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'dashboard-quick-complete-'")
        ).firstMatch
        XCTAssertTrue(quickComplete.waitForExistence(timeout: 3))
        quickComplete.tap()

        let confirmation = app.alerts["确认完成？"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        confirmation.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '扫地'")).firstMatch.exists)

        quickComplete.tap()
        app.alerts["确认完成？"].buttons["确认完成"].tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '扫地'")).firstMatch.exists)
    }
}
