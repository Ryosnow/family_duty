import XCTest

final class AccessibilityUITests: XCTestCase {
    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testKeyActionsRemainAvailableAtLargestTextSizeAfterRotation() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-seedDashboardTask",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()

        let task = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'dashboard-task-' AND label CONTAINS '扫地'" )).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 4))
        XCTAssertTrue(task.isHittable)
        XCTAssertTrue(app.buttons["dashboard-add-temporary-toolbar"].exists)

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(task.waitForExistence(timeout: 3))
        app.buttons["轮班"].tap()
        XCTAssertTrue(app.buttons["rotation-add-rule"].waitForExistence(timeout: 3))
        app.buttons["设置"].tap()
        XCTAssertTrue(app.buttons["settings-add-member"].waitForExistence(timeout: 3))
    }

    func testDashboardShowsActionableEmptyStates() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedMember"]
        app.launch()

        XCTAssertTrue(app.staticTexts["今天没有待办"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["还没有完成记录"].exists)
        XCTAssertTrue(app.buttons["dashboard-add-temporary-toolbar"].exists)
    }
}
