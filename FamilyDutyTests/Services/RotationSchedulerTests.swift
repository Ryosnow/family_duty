import XCTest
@testable import FamilyDuty

final class RotationSchedulerTests: XCTestCase {
    func testAssigneeRotatesEachWeekFromTheStartWeek() {
        let calendar = Calendar(identifier: .iso8601)
        let first = FamilyMember(name: "小明", sortOrder: 0)
        let second = FamilyMember(name: "小红", sortOrder: 1)
        let start = calendar.date(from: DateComponents(weekday: 2, weekOfYear: 1, yearForWeekOfYear: 2026))!
        let rule = ChoreRule(title: "扫地", weekday: 2, startOfRotationWeek: start, participants: [first, second])
        let target = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!

        XCTAssertEqual(RotationScheduler().assignee(for: rule, weekOf: target, calendar: calendar)?.name, "小红")
    }
}
