import Foundation

enum ReportKind: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "日报"
        case .week: "周报"
        case .month: "月报"
        }
    }

    func period(for date: Date) -> ReportPeriod {
        switch self {
        case .day: .day(date)
        case .week: .week(date)
        case .month: .month(date)
        }
    }
}

struct ReportsViewModel: Equatable {
    private(set) var period: ReportPeriod
    let calendar: Calendar
    private var selectionAnchorDate: Date

    init(initialPeriod: ReportPeriod = .day(.now), calendar: Calendar = .current) {
        self.period = initialPeriod
        self.calendar = calendar
        self.selectionAnchorDate = initialPeriod.anchorDate
    }

    var reportKind: ReportKind {
        get {
            switch period {
            case .day: .day
            case .week: .week
            case .month: .month
            }
        }
        set {
            period = newValue.period(for: selectionAnchorDate)
        }
    }

    var anchorDate: Date {
        get { period.anchorDate }
        set { setAnchorDate(newValue) }
    }

    var periodTitle: String {
        guard let interval = period.dateInterval(calendar: calendar) else {
            return anchorDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN")))
        }

        switch period {
        case .day:
            return interval.start.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN")))
        case .week:
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let startText = interval.start.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN")))
            let endText = end.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
            return "\(startText) – \(endText)"
        case .month:
            return interval.start.formatted(.dateTime.year().month().locale(Locale(identifier: "zh_CN")))
        }
    }

    mutating func select(_ kind: ReportKind) {
        reportKind = kind
    }

    mutating func move(by value: Int) {
        period = period.advanced(by: value, calendar: calendar)
    }

    mutating func setAnchorDate(_ date: Date) {
        selectionAnchorDate = date
        period = reportKind.period(for: date)
    }
}
