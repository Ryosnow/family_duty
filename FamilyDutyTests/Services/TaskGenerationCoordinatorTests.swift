import SwiftData
import XCTest
@testable import FamilyDuty

@MainActor
final class TaskGenerationCoordinatorTests: XCTestCase {
    func testRefreshMaintainsAnEightWeekTaskHorizon() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = testCalendar
        let today = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let rule = ChoreRule(
            title: "扫地",
            weekday: calendar.component(.weekday, from: today),
            startOfRotationWeek: today,
            participants: [member]
        )
        context.insert(member)
        context.insert(rule)

        try TaskGenerationCoordinator(context: context, calendar: calendar, horizonWeeks: 8)
            .refresh(for: [rule], now: today)

        let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
        XCTAssertGreaterThanOrEqual(tasks.count, 8)
        XCTAssertLessThanOrEqual(tasks.count, 9)
    }

    func testRefreshIsIdempotentWhenCalledAgainAtTheSameDate() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = testCalendar
        let today = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let rule = ChoreRule(
            title: "洗碗",
            weekday: calendar.component(.weekday, from: today),
            startOfRotationWeek: today,
            participants: [member]
        )
        context.insert(member)
        context.insert(rule)

        let coordinator = TaskGenerationCoordinator(context: context, calendar: calendar, horizonWeeks: 8)
        try coordinator.refresh(for: [rule], now: today)
        let firstCount = try context.fetchCount(FetchDescriptor<ChoreTask>())

        try coordinator.refresh(for: [rule], now: today)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ChoreTask>()), firstCount)
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
