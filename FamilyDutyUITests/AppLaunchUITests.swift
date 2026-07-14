import XCTest

final class AppLaunchUITests: XCTestCase {
    func testLaunchShowsPrimaryDestinations() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedMember"]
        app.launch()

        XCTAssertTrue(app.buttons["首页"].exists)
        XCTAssertTrue(app.buttons["轮班"].exists)
        XCTAssertTrue(app.buttons["设置"].exists)
    }
}
