import XCTest

final class HistoryFlowUITests: XCTestCase {
    func testHistoryShowsAllRecordsAndOpensDetail() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedHistory"]
        app.launch()

        app.buttons["历史"].tap()

        XCTAssertTrue(app.navigationBars["历史"].waitForExistence(timeout: 3))
        let recordRows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'history-record-'"))
        XCTAssertGreaterThanOrEqual(recordRows.count, 1)

        recordRows.element(boundBy: 0).tap()

        XCTAssertTrue(app.navigationBars["完成详情"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["history-detail"].exists)
        XCTAssertTrue(app.buttons["history-recreate"].exists)
    }

    func testHistorySearchFiltersTaskNamesAndCanPrefillRecreatedTask() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedHistory"]
        app.launch()
        app.buttons["历史"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("Test Task")

        let recordRows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'history-record-'"))
        XCTAssertEqual(recordRows.count, 1)
        recordRows.firstMatch.tap()
        app.buttons["history-recreate"].tap()

        XCTAssertTrue(app.navigationBars["新增临时任务"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["任务名称"].value as? String, "Test Task")
        XCTAssertEqual(app.textFields["得分"].value as? String, "1")
    }
}
