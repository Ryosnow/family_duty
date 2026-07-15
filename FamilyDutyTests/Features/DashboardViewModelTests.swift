import XCTest
@testable import FamilyDuty

final class DashboardViewModelTests: XCTestCase {
    func testPendingTasksExcludeCompletedTasks() {
        let pending = ChoreTask(title: "扫地", scheduledDate: .now)
        let completed = ChoreTask(title: "洗碗", scheduledDate: .now, status: .completed)
        XCTAssertEqual(DashboardViewModel.pendingTasks(from: [pending, completed]).count, 1)
    }

    func testTasksAreSeparatedIntoTodayLaterThisWeekAndTemporary() {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_721_024_400)
        let today = ChoreTask(title: "扫地", scheduledDate: now)
        let later = ChoreTask(title: "洗碗", scheduledDate: calendar.date(byAdding: .day, value: 2, to: now)!)
        let nextWeek = ChoreTask(title: "擦窗", scheduledDate: calendar.date(byAdding: .day, value: 8, to: now)!)
        let temporary = ChoreTask(title: "收快递", scheduledDate: now, isTemporary: true)

        XCTAssertEqual(DashboardViewModel.todayTasks(from: [today, later, nextWeek, temporary], now: now, calendar: calendar).map(\.title), ["扫地"])
        XCTAssertEqual(DashboardViewModel.laterThisWeekTasks(from: [today, later, nextWeek, temporary], now: now, calendar: calendar).map(\.title), ["洗碗"])
        XCTAssertEqual(
            DashboardViewModel.temporaryTasks(from: [today, later, nextWeek, temporary], now: now, calendar: calendar).map(\.title),
            ["收快递"]
        )
    }

    func testTodayProgressIncludesTemporaryTasksAndExcludesCancelledTasks() {
        let calendar = testCalendar
        let now = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let pendingTemporary = ChoreTask(title: "收快递", scheduledDate: now, isTemporary: true)
        let completedTemporary = ChoreTask(
            title: "临时整理",
            scheduledDate: now,
            isTemporary: true,
            status: .completed
        )
        let cancelled = ChoreTask(title: "已取消", scheduledDate: now, status: .cancelled)

        let progress = DashboardViewModel.todayProgress(
            from: [pendingTemporary, completedTemporary, cancelled],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(progress.completed, 1)
        XCTAssertEqual(progress.total, 2)
    }

    func testOverdueTasksIncludePendingTasksPastTheirEffectiveDeadline() {
        let calendar = testCalendar
        let now = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let scheduledDate = date(year: 2026, month: 7, day: 10, calendar: calendar)
        let task = ChoreTask(title: "扫地", scheduledDate: scheduledDate)

        XCTAssertEqual(
            DashboardViewModel.overdueTasks(from: [task], now: now, calendar: calendar).map(\.title),
            ["扫地"]
        )
    }

    func testOverdueTasksUseExplicitDeadlineAndSortByDeadlineThenScheduledDate() {
        let calendar = testCalendar
        let now = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let first = ChoreTask(
            title: "擦桌子",
            scheduledDate: date(year: 2026, month: 7, day: 8, calendar: calendar),
            deadline: date(year: 2026, month: 7, day: 12, calendar: calendar)
        )
        let second = ChoreTask(
            title: "浇花",
            scheduledDate: date(year: 2026, month: 7, day: 9, calendar: calendar),
            deadline: date(year: 2026, month: 7, day: 13, calendar: calendar)
        )

        XCTAssertEqual(
            DashboardViewModel.overdueTasks(from: [second, first], now: now, calendar: calendar).map(\.title),
            ["擦桌子", "浇花"]
        )
    }

    func testCompletedAndCancelledOverdueTasksAreExcluded() {
        let calendar = testCalendar
        let now = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let scheduledDate = date(year: 2026, month: 7, day: 10, calendar: calendar)
        let completed = ChoreTask(title: "完成", scheduledDate: scheduledDate, status: .completed)
        let cancelled = ChoreTask(title: "取消", scheduledDate: scheduledDate, status: .cancelled)

        XCTAssertTrue(DashboardViewModel.overdueTasks(from: [completed, cancelled], now: now, calendar: calendar).isEmpty)
    }

    func testOverdueTemporaryTasksAreNotRepeatedInTemporarySection() {
        let calendar = testCalendar
        let now = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let task = ChoreTask(
            title: "收快递",
            scheduledDate: date(year: 2026, month: 7, day: 10, calendar: calendar),
            isTemporary: true
        )

        XCTAssertEqual(DashboardViewModel.overdueTasks(from: [task], now: now, calendar: calendar).count, 1)
        XCTAssertTrue(DashboardViewModel.temporaryTasks(from: [task], now: now, calendar: calendar).isEmpty)
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
