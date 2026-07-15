import Foundation
import XCTest
@testable import FamilyDuty

final class ReportsViewModelTests: XCTestCase {
    func testSelectingPeriodKeepsAnchorDateAndChangingPeriodMovesBySelectedUnit() {
        let calendar = testCalendar
        let anchor = date(year: 2026, month: 7, day: 15, calendar: calendar)
        var viewModel = ReportsViewModel(initialPeriod: .day(anchor), calendar: calendar)

        XCTAssertEqual(viewModel.reportKind, .day)

        viewModel.select(.week)
        XCTAssertEqual(viewModel.period, .week(anchor))

        viewModel.move(by: 1)
        XCTAssertEqual(
            viewModel.period,
            .week(calendar.date(byAdding: .weekOfYear, value: 1, to: anchor)!)
        )

        viewModel.select(.month)
        XCTAssertEqual(
            viewModel.period,
            .month(calendar.date(byAdding: .weekOfYear, value: 1, to: anchor)!)
        )
    }

    func testChangingAnchorDatePreservesSelectedReportKind() {
        let calendar = testCalendar
        let anchor = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let nextMonth = date(year: 2026, month: 8, day: 22, calendar: calendar)
        var viewModel = ReportsViewModel(initialPeriod: .month(anchor), calendar: calendar)

        viewModel.setAnchorDate(nextMonth)

        XCTAssertEqual(viewModel.reportKind, .month)
        XCTAssertEqual(viewModel.period, .month(nextMonth))
    }

    func testPeriodTitleUsesLocalizedChineseDateText() {
        let calendar = testCalendar
        let anchor = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let viewModel = ReportsViewModel(initialPeriod: .week(anchor), calendar: calendar)

        XCTAssertTrue(viewModel.periodTitle.contains("2026"))
        XCTAssertTrue(viewModel.periodTitle.contains("月"))
        XCTAssertFalse(viewModel.periodTitle.contains("interval.start"))
        XCTAssertFalse(viewModel.periodTitle.contains("formatted"))
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
