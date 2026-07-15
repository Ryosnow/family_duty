import XCTest

final class ReportsFlowUITests: XCTestCase {
    func testReportsShowsCurrentWeekPlannedWorkload() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedTaskBoard"]
        app.launch()

        app.buttons["报表"].tap()

        XCTAssertTrue(app.staticTexts["本周计划工作量"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["planned-workload-summary"].exists)
        XCTAssertTrue(app.staticTexts["已分配任务"].exists)
        XCTAssertTrue(app.staticTexts["计划分值"].exists)
        XCTAssertTrue(app.staticTexts["小明"].exists)
        XCTAssertTrue(app.staticTexts["小红"].exists)
    }

    func testReportsTabShowsDailyMemberWorkloadAndPeriodControls() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedTaskBoard"]
        app.launch()

        let reportsTab = app.buttons["报表"]
        XCTAssertTrue(reportsTab.waitForExistence(timeout: 3))
        reportsTab.tap()

        XCTAssertTrue(app.navigationBars["报表"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["reports-view"].exists)
        XCTAssertTrue(app.buttons["reports-previous-period"].exists)
        XCTAssertTrue(app.buttons["reports-next-period"].exists)
        XCTAssertTrue(app.staticTexts["小明"].exists)
        XCTAssertTrue(app.staticTexts["小红"].exists)
    }

    func testReportsCanSwitchToWeeklyAndMonthlyHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedTaskBoard"]
        app.launch()

        app.buttons["报表"].tap()
        XCTAssertTrue(app.buttons["周报"].waitForExistence(timeout: 3))

        app.buttons["周报"].tap()
        XCTAssertTrue(app.staticTexts["每日趋势"].waitForExistence(timeout: 2))

        app.buttons["月报"].tap()
        XCTAssertTrue(app.staticTexts["月报总览"].waitForExistence(timeout: 2))
        app.buttons["reports-previous-period"].tap()
        XCTAssertTrue(app.buttons["reports-next-period"].exists)
    }
}
