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
        XCTAssertEqual(DashboardViewModel.temporaryTasks(from: [today, later, nextWeek, temporary]).map(\.title), ["收快递"])
    }
}
