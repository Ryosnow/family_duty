import XCTest
@testable import FamilyDuty

final class FamilyDutyTests: XCTestCase {
    func testRootViewCanBeCreated() {
        _ = AppRootView()
    }

    func testScoringSchemaCanLoadInMemoryContainer() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()

        XCTAssertNotNil(container)
    }
}
