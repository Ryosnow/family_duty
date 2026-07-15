import Foundation
import XCTest
@testable import FamilyDuty

final class TaskDeadlineServiceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testNilDeadlineUsesScheduledDayAsEffectiveDeadline() {
        let scheduledDate = date(year: 2026, month: 7, day: 15)
        let task = ChoreTask(title: "扫地", scheduledDate: scheduledDate)

        XCTAssertEqual(
            TaskDeadlineService.effectiveDeadline(for: task, calendar: calendar),
            calendar.startOfDay(for: scheduledDate)
        )
    }

    func testTaskIsNotOverdueOnItsDeadlineDayButIsOverdueTheNextDay() {
        let deadline = date(year: 2026, month: 7, day: 15)
        let task = ChoreTask(title: "洗碗", scheduledDate: deadline, deadline: deadline)

        XCTAssertFalse(
            TaskDeadlineService.isOverdue(task, now: date(year: 2026, month: 7, day: 15), calendar: calendar)
        )
        XCTAssertTrue(
            TaskDeadlineService.isOverdue(task, now: date(year: 2026, month: 7, day: 16), calendar: calendar)
        )
    }

    func testCompletedAndCancelledTasksAreNeverOverdue() {
        let deadline = date(year: 2026, month: 7, day: 15)
        let completed = ChoreTask(title: "完成", scheduledDate: deadline, deadline: deadline, status: .completed)
        let cancelled = ChoreTask(title: "取消", scheduledDate: deadline, deadline: deadline, status: .cancelled)

        XCTAssertFalse(
            TaskDeadlineService.isOverdue(completed, now: date(year: 2026, month: 7, day: 16), calendar: calendar)
        )
        XCTAssertFalse(
            TaskDeadlineService.isOverdue(cancelled, now: date(year: 2026, month: 7, day: 16), calendar: calendar)
        )
    }

    func testDeadlineValidationRejectsDateBeforeScheduledDate() {
        let scheduledDate = date(year: 2026, month: 7, day: 15)
        let deadline = date(year: 2026, month: 7, day: 14)

        XCTAssertThrowsError(
            try TaskDeadlineService.validate(deadline: deadline, scheduledDate: scheduledDate, calendar: calendar)
        ) { error in
            XCTAssertEqual(error as? TaskDeadlineValidationError, .beforeScheduledDate)
        }
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
