import SwiftUI
import XCTest
@testable import FamilyDuty

final class FamilyDutyMemberColorTests: XCTestCase {
    func testMemberColorOptionsHaveStableUniqueNames() {
        let names = FamilyDutyMemberColor.options.map(\.name)

        XCTAssertFalse(names.isEmpty)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testUnknownColorFallsBackToFirstOption() {
        XCTAssertEqual(
            FamilyDutyMemberColor.colorName(for: "unknown"),
            FamilyDutyMemberColor.options[0].name
        )
    }

    func testDefaultColorCyclesBySortOrder() {
        let options = FamilyDutyMemberColor.options

        XCTAssertEqual(FamilyDutyMemberColor.defaultName(forSortOrder: 0), options[0].name)
        XCTAssertEqual(FamilyDutyMemberColor.defaultName(forSortOrder: options.count), options[0].name)
    }
}
