import Foundation
import XCTest
@testable import FamilyDuty

final class PlannedWorkloadViewModelTests: XCTestCase {
    func testWeeklySummariesAggregateAssignedTasksAcrossStatuses() {
        let calendar = testCalendar
        let wednesday = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let monday = calendar.dateInterval(of: .weekOfYear, for: wednesday)!.start
        let first = FamilyMember(name: "小明", sortOrder: 0)
        let second = FamilyMember(name: "小红", sortOrder: 1)

        let pendingTask = ChoreTask(title: "扫地", scheduledDate: monday, score: 3, assignee: first)
        let completedTask = ChoreTask(title: "洗碗", scheduledDate: wednesday, score: 2, assignee: first, status: .completed)
        let cancelledTask = ChoreTask(title: "擦桌子", scheduledDate: wednesday, score: 1, assignee: second, status: .cancelled)
        let unassignedTask = ChoreTask(title: "待领取", scheduledDate: wednesday, score: 8)

        let summaries = PlannedWorkloadViewModel.weeklySummaries(
            for: wednesday,
            tasks: [pendingTask, completedTask, cancelledTask, unassignedTask],
            members: [first, second],
            calendar: calendar
        )

        XCTAssertEqual(summaries.map(\.memberName), ["小明", "小红"])
        XCTAssertEqual(summaries.map(\.assignedCount), [2, 1])
        XCTAssertEqual(summaries.map(\.plannedScore), [5, 1])
    }

    func testWeeklySummariesExcludeTasksOutsideWeekAndKeepMembersWithNoAssignments() {
        let calendar = testCalendar
        let anchor = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: anchor)!.start
        let previousWeek = calendar.date(byAdding: .day, value: -1, to: weekStart)!
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        let first = FamilyMember(name: "小明", sortOrder: 0)
        let second = FamilyMember(name: "小红", sortOrder: 1)

        let outsideBefore = ChoreTask(title: "上周任务", scheduledDate: previousWeek, score: 5, assignee: first)
        let outsideAfter = ChoreTask(title: "下周任务", scheduledDate: nextWeek, score: 6, assignee: first)

        let summaries = PlannedWorkloadViewModel.weeklySummaries(
            for: anchor,
            tasks: [outsideBefore, outsideAfter],
            members: [first, second],
            calendar: calendar
        )

        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(summaries[0].assignedCount, 0)
        XCTAssertEqual(summaries[0].plannedScore, 0)
        XCTAssertEqual(summaries[1].assignedCount, 0)
        XCTAssertEqual(summaries[1].plannedScore, 0)
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
