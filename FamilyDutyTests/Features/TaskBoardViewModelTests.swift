import Foundation
import XCTest
@testable import FamilyDuty

final class TaskBoardViewModelTests: XCTestCase {
    func testTodayTasksIncludeAllStatusesAndExcludeOtherDays() {
        let calendar = testCalendar
        let today = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let pending = ChoreTask(title: "待处理", scheduledDate: today)
        let completed = ChoreTask(title: "已完成", scheduledDate: today, status: .completed)
        let cancelled = ChoreTask(title: "已取消", scheduledDate: today, status: .cancelled)
        let old = ChoreTask(title: "昨天", scheduledDate: yesterday)
        let future = ChoreTask(title: "明天", scheduledDate: tomorrow)

        let result = TaskBoardViewModel.todayTasks(
            from: [pending, completed, cancelled, old, future],
            now: today,
            calendar: calendar
        )

        XCTAssertEqual(Set(result.map(\.title)), ["待处理", "已完成", "已取消"])
    }

    func testSectionsSortPendingByDeadlineCompletedByLatestRecordAndCancelledByDate() {
        let calendar = testCalendar
        let today = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let earlyPending = ChoreTask(
            title: "早截止",
            scheduledDate: today,
            deadline: date(year: 2026, month: 7, day: 15, calendar: calendar)
        )
        let latePending = ChoreTask(
            title: "晚截止",
            scheduledDate: today,
            deadline: date(year: 2026, month: 7, day: 17, calendar: calendar)
        )
        let firstCompleted = ChoreTask(title: "较早完成", scheduledDate: today, status: .completed)
        let latestCompleted = ChoreTask(title: "最近完成", scheduledDate: today, status: .completed)
        let firstRecord = CompletionRecord(
            task: firstCompleted,
            completedBy: member,
            completedAt: date(year: 2026, month: 7, day: 15, calendar: calendar)
        )
        let latestRecord = CompletionRecord(
            task: latestCompleted,
            completedBy: member,
            completedAt: calendar.date(byAdding: .hour, value: 2, to: firstRecord.completedAt)!
        )
        let laterCancelled = ChoreTask(
            title: "后取消",
            scheduledDate: calendar.date(byAdding: .hour, value: 2, to: today)!,
            status: .cancelled
        )
        let earlierCancelled = ChoreTask(title: "先取消", scheduledDate: today, status: .cancelled)

        let sections = TaskBoardViewModel.sections(
            from: [latePending, latestCompleted, laterCancelled, earlyPending, firstCompleted, earlierCancelled],
            records: [firstRecord, latestRecord],
            now: today,
            calendar: calendar
        )

        XCTAssertEqual(sections.pending.map(\.title), ["早截止", "晚截止"])
        XCTAssertEqual(sections.completed.map(\.title), ["最近完成", "较早完成"])
        XCTAssertEqual(sections.cancelled.map(\.title), ["先取消", "后取消"])
    }

    func testLatestCompletionRecordReturnsMostRecentRecordAndMissingRecordReturnsNil() {
        let calendar = testCalendar
        let today = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "已完成", scheduledDate: today, status: .completed)
        let older = CompletionRecord(task: task, completedBy: member, completedAt: today)
        let newer = CompletionRecord(
            task: task,
            completedBy: member,
            completedAt: calendar.date(byAdding: .hour, value: 1, to: today)!
        )
        let missing = ChoreTask(title: "无记录", scheduledDate: today, status: .completed)

        XCTAssertEqual(
            TaskBoardViewModel.latestCompletionRecord(for: task, from: [older, newer])?.id,
            newer.id
        )
        XCTAssertNil(TaskBoardViewModel.latestCompletionRecord(for: missing, from: [older, newer]))
    }

    func testTodayWorkloadSummariesUseCompletionWorkDateAndIncludeZeroMembers() {
        let calendar = testCalendar
        let today = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let zeroMember = FamilyMember(name: "小红", sortOrder: 1)
        let task = ChoreTask(title: "晚完成的任务", scheduledDate: today, score: 3, status: .completed)
        let record = CompletionRecord(
            task: task,
            completedBy: member,
            completedAt: calendar.date(byAdding: .day, value: 1, to: today)!,
            calendar: calendar
        )

        let summaries = TaskBoardViewModel.todayWorkloadSummaries(
            from: [record],
            members: [member, zeroMember],
            now: today,
            calendar: calendar
        )

        XCTAssertEqual(summaries.map(\.memberName), ["小明", "小红"])
        XCTAssertEqual(summaries.map(\.completedCount), [1, 0])
        XCTAssertEqual(summaries.map(\.totalScore), [3, 0])
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
