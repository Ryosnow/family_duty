import XCTest

final class TaskBoardFlowUITests: XCTestCase {
    func testTaskBoardShowsAllTodayStatusesAndExcludesTomorrow() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedTaskBoard"]
        app.launch()

        let taskBoardTab = app.buttons["任务面板"]
        XCTAssertTrue(taskBoardTab.waitForExistence(timeout: 3))
        taskBoardTab.tap()

        XCTAssertTrue(app.staticTexts["任务面板"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'task-board-task-' AND label CONTAINS '面板待处理'" )).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["面板已完成"].exists)
        XCTAssertTrue(app.staticTexts["面板已取消"].exists)
        XCTAssertTrue(app.staticTexts["待处理"].exists)
        XCTAssertTrue(app.staticTexts["已完成"].exists)
        XCTAssertTrue(app.staticTexts["已取消"].exists)
        XCTAssertFalse(app.staticTexts["面板明天"].exists)
    }

    func testCompletingPendingTaskRemovesItFromPendingActions() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedTaskBoard"]
        app.launch()

        app.buttons["任务面板"].tap()
        let task = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'task-board-task-' AND label CONTAINS '面板待处理'" )).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 3))
        task.tap()

        let completeButton = app.buttons["确认完成"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 2))
        completeButton.tap()

        XCTAssertFalse(task.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["面板待处理"].waitForExistence(timeout: 2))
    }

    func testUndoingCompletedTaskReturnsItToPendingActions() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedTaskBoard"]
        app.launch()

        app.buttons["任务面板"].tap()
        let completedTask = app.staticTexts["面板已完成"]
        XCTAssertTrue(completedTask.waitForExistence(timeout: 3))
        let undoAction = app.buttons.matching(NSPredicate(format: "label == '撤销完成'" )).firstMatch
        XCTAssertTrue(undoAction.waitForExistence(timeout: 2))
        undoAction.tap()

        let confirmation = app.alerts["撤销完成？"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        confirmation.buttons["撤销完成"].tap()

        XCTAssertTrue(app.staticTexts["面板已完成"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["待处理"].waitForExistence(timeout: 2))
    }
}
