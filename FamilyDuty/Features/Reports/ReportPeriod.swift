import Foundation

enum ReportPeriod: Equatable {
    case day(Date)
    case week(Date)
    case month(Date)

    var anchorDate: Date {
        switch self {
        case let .day(date), let .week(date), let .month(date):
            return date
        }
    }

    func dateInterval(calendar: Calendar) -> DateInterval? {
        switch self {
        case .day:
            return calendar.dateInterval(of: .day, for: anchorDate)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: anchorDate)
        case .month:
            return calendar.dateInterval(of: .month, for: anchorDate)
        }
    }

    func advanced(by value: Int, calendar: Calendar) -> ReportPeriod {
        let component: Calendar.Component
        switch self {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        }
        let date = calendar.date(byAdding: component, value: value, to: anchorDate) ?? anchorDate
        switch self {
        case .day: return .day(date)
        case .week: return .week(date)
        case .month: return .month(date)
        }
    }

    var title: String {
        switch self {
        case let .day(date): return date.formatted(date: .abbreviated, time: .omitted)
        case let .week(date): return "周报 · \(date.formatted(date: .abbreviated, time: .omitted))"
        case let .month(date): return date.formatted(.dateTime.year().month())
        }
    }
}
