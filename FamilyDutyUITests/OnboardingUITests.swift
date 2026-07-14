import XCTest

final class OnboardingUITests: XCTestCase {
    func testFirstLaunchCreatesMemberAndFirstRule() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["欢迎使用家庭值日"].waitForExistence(timeout: 3))
        app.textFields["成员姓名"].tap()
        app.textFields["成员姓名"].typeText("小明")
        app.textFields["首个固定任务"].tap()
        app.textFields["首个固定任务"].typeText("扫地")
        app.buttons["开始使用"].tap()

        XCTAssertTrue(app.buttons["首页"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["轮班"].exists)
    }
}
