import Foundation
import SwiftData
import XCTest
@testable import FamilyDuty

final class HistoryViewModelTests: XCTestCase {
    func testFiltersRecordsByTaskDateMemberAndTitle() throws {
        let calendar = testCalendar
        let today = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let yesterday = date(year: 2026, month: 7, day: 14, calendar: calendar)
        let firstMember = FamilyMember(name: "小明", sortOrder: 0)
        let secondMember = FamilyMember(name: "小红", sortOrder: 1)
        let matching = makeRecord(
            title: "擦桌子",
            scheduledDate: today,
            completedAt: today.addingTimeInterval(3600),
            member: firstMember,
            calendar: calendar
        )
        let wrongMember = makeRecord(
            title: "擦桌子",
            scheduledDate: today,
            completedAt: today.addingTimeInterval(7200),
            member: secondMember,
            calendar: calendar
        )
        let wrongDate = makeRecord(
            title: "扫地",
            scheduledDate: yesterday,
            completedAt: yesterday.addingTimeInterval(3600),
            member: firstMember,
            calendar: calendar
        )
        let filter = HistoryFilter(
            dateScope: .custom(start: today, end: today),
            member: .member(firstMember.id),
            titleQuery: " 桌子 "
        )

        let result = HistoryViewModel.filteredRecords(
            from: [wrongDate, wrongMember, matching],
            filter: filter,
            calendar: calendar,
            now: today
        )

        XCTAssertEqual(result.map(\.id), [matching.id])
    }

    func testUsesLatestCompletionRecordForEachTaskAndSortsNewestFirst() throws {
        let calendar = testCalendar
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "洗碗", scheduledDate: date(year: 2026, month: 7, day: 15, calendar: calendar))
        let older = CompletionRecord(
            task: task,
            completedBy: member,
            completedAt: date(year: 2026, month: 7, day: 15, hour: 8, calendar: calendar),
            calendar: calendar
        )
        let newer = CompletionRecord(
            task: task,
            completedBy: member,
            completedAt: date(year: 2026, month: 7, day: 15, hour: 10, calendar: calendar),
            calendar: calendar
        )
        let other = makeRecord(
            title: "倒垃圾",
            scheduledDate: date(year: 2026, month: 7, day: 15, calendar: calendar),
            completedAt: date(year: 2026, month: 7, day: 15, hour: 9, calendar: calendar),
            member: member,
            calendar: calendar
        )

        let result = HistoryViewModel.filteredRecords(
            from: [older, other, newer],
            filter: HistoryFilter(),
            calendar: calendar,
            now: .now
        )

        XCTAssertEqual(result.map(\.id), [newer.id, other.id])
    }

    func testHistoricalMemberSnapshotCanBeFilteredAfterMemberDeletion() throws {
        let calendar = testCalendar
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let record = makeRecord(
            title: "整理房间",
            scheduledDate: date(year: 2026, month: 7, day: 15, calendar: calendar),
            completedAt: date(year: 2026, month: 7, day: 15, hour: 12, calendar: calendar),
            member: member,
            calendar: calendar
        )
        record.completedBy = nil
        let filter = HistoryFilter(member: .historicalName("小明"))

        let result = HistoryViewModel.filteredRecords(
            from: [record],
            filter: filter,
            calendar: calendar,
            now: .now
        )

        XCTAssertEqual(result.map(\.id), [record.id])
        XCTAssertEqual(HistoryViewModel.displayName(for: record), "小明")
    }

    func testRecreationDraftCopiesOnlyTitleAndScore() throws {
        let calendar = testCalendar
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(
            title: "浇花",
            scheduledDate: date(year: 2026, month: 7, day: 15, calendar: calendar),
            deadline: date(year: 2026, month: 7, day: 17, calendar: calendar),
            score: 3,
            assignee: member,
            rule: ChoreRule(
                title: "浇花",
                weekday: 4,
                startOfRotationWeek: date(year: 2026, month: 7, day: 13, calendar: calendar),
                participants: [member]
            )
        )
        let record = CompletionRecord(task: task, completedBy: member, calendar: calendar)

        let draft = try XCTUnwrap(HistoryViewModel.recreationDraft(for: record))

        XCTAssertEqual(draft.title, "浇花")
        XCTAssertEqual(draft.score, 3)
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 0, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func makeRecord(
        title: String,
        scheduledDate: Date,
        completedAt: Date,
        member: FamilyMember,
        calendar: Calendar
    ) -> CompletionRecord {
        let task = ChoreTask(title: title, scheduledDate: scheduledDate, assignee: member)
        return CompletionRecord(task: task, completedBy: member, completedAt: completedAt, calendar: calendar)
    }
}
