import Foundation
import XCTest
@testable import FamilyDuty

final class ScoreReportViewModelTests: XCTestCase {
    func testDailySummariesIncludeZeroScoreMembersAndSumCompletedScores() throws {
        let calendar = testCalendar
        let day = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let first = FamilyMember(name: "小明", sortOrder: 0)
        let second = FamilyMember(name: "小红", sortOrder: 1)
        let firstTask = ChoreTask(title: "扫地", scheduledDate: day, score: 3, status: .completed)
        let secondDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let otherTask = ChoreTask(title: "洗碗", scheduledDate: secondDay, score: 2, status: .completed)
        let record = CompletionRecord(task: firstTask, completedBy: first)
        let otherRecord = CompletionRecord(task: otherTask, completedBy: second)

        let summaries = ScoreReportViewModel.summaries(
            for: .day(day),
            members: [first, second],
            records: [record, otherRecord],
            calendar: calendar
        )

        XCTAssertEqual(summaries.map(\.memberName), ["小明", "小红"])
        XCTAssertEqual(summaries.map(\.completedCount), [1, 0])
        XCTAssertEqual(summaries.map(\.totalScore), [3, 0])
    }

    func testWeeklyDataPointsUseWorkDateAndAggregateByMemberAndDay() throws {
        let calendar = testCalendar
        let week = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let firstTask = ChoreTask(title: "扫地", scheduledDate: week, score: 3, status: .completed)
        let secondTask = ChoreTask(title: "拖地", scheduledDate: week, score: 2, status: .completed)
        let firstRecord = CompletionRecord(task: firstTask, completedBy: member)
        let secondRecord = CompletionRecord(task: secondTask, completedBy: member)

        let points = ScoreReportViewModel.dailyDataPoints(
            for: .week(week),
            records: [firstRecord, secondRecord],
            calendar: calendar
        )

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.date, calendar.startOfDay(for: week))
        XCTAssertEqual(points.first?.memberName, "小明")
        XCTAssertEqual(points.first?.taskCount, 2)
        XCTAssertEqual(points.first?.totalScore, 5)
    }

    func testDuplicateCompletionRecordsOnlyUseMostRecentRecord() throws {
        let calendar = testCalendar
        let day = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "扫地", scheduledDate: day, score: 3, status: .completed)
        let older = CompletionRecord(task: task, completedBy: member, completedAt: day)
        let newer = CompletionRecord(
            task: task,
            completedBy: member,
            completedAt: calendar.date(byAdding: .hour, value: 1, to: day)!
        )

        let latest = ScoreReportViewModel.latestRecords(from: [older, newer])

        XCTAssertEqual(latest.count, 1)
        XCTAssertEqual(latest.first?.id, newer.id)
    }

    func testPeriodDateIntervalUsesCalendarMonthBoundary() throws {
        let calendar = testCalendar
        let date = self.date(year: 2026, month: 7, day: 15, calendar: calendar)

        let interval = try XCTUnwrap(ReportPeriod.month(date).dateInterval(calendar: calendar))

        XCTAssertEqual(interval.start, self.date(year: 2026, month: 7, day: 1, calendar: calendar))
        XCTAssertEqual(interval.end, self.date(year: 2026, month: 8, day: 1, calendar: calendar))
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
