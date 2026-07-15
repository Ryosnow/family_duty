import Foundation

enum HistoryDateScope: Equatable, Identifiable {
    case all
    case today
    case lastSevenDays
    case thisMonth
    case custom(start: Date, end: Date)

    var id: String {
        switch self {
        case .all: "all"
        case .today: "today"
        case .lastSevenDays: "last-seven-days"
        case .thisMonth: "this-month"
        case let .custom(start, end):
            "custom-" + String(start.timeIntervalSinceReferenceDate) + "-" + String(end.timeIntervalSinceReferenceDate)
        }
    }

    var title: String {
        switch self {
        case .all: "全部日期"
        case .today: "今天"
        case .lastSevenDays: "最近 7 天"
        case .thisMonth: "本月"
        case .custom: "自定义日期"
        }
    }

    func dateInterval(calendar: Calendar, now: Date) -> DateInterval? {
        switch self {
        case .all:
            return nil
        case .today:
            return calendar.dateInterval(of: .day, for: now)
        case .lastSevenDays:
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
            return DateInterval(start: start, end: end)
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
        case let .custom(start, end):
            let normalizedStart = calendar.startOfDay(for: min(start, end))
            let lastDay = calendar.startOfDay(for: max(start, end))
            let normalizedEnd = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
            return DateInterval(start: normalizedStart, end: normalizedEnd)
        }
    }
}

enum HistoryMemberFilter: Equatable, Hashable, Identifiable {
    case all
    case member(UUID)
    case historicalName(String)

    var id: String {
        switch self {
        case .all: "all"
        case let .member(id): "member-" + id.uuidString
        case let .historicalName(name): "historical-" + name
        }
    }
}

struct HistoryFilter: Equatable {
    var dateScope: HistoryDateScope = .all
    var member: HistoryMemberFilter = .all
    var titleQuery = ""

    init(
        dateScope: HistoryDateScope = .all,
        member: HistoryMemberFilter = .all,
        titleQuery: String = ""
    ) {
        self.dateScope = dateScope
        self.member = member
        self.titleQuery = titleQuery
    }
}

enum HistoryViewModel {
    static func filteredRecords(
        from records: [CompletionRecord],
        filter: HistoryFilter,
        calendar: Calendar,
        now: Date
    ) -> [CompletionRecord] {
        let latestRecords = ScoreReportViewModel.latestRecords(from: records)
        let interval = filter.dateScope.dateInterval(calendar: calendar, now: now)
        let normalizedQuery = filter.titleQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        return latestRecords
            .filter { record in
                guard contains(record.workDate, in: interval) else { return false }
                guard matchesMember(record, filter: filter.member) else { return false }
                guard normalizedQuery.isEmpty else {
                    return record.task?.title.localizedCaseInsensitiveContains(normalizedQuery) == true
                }
                return true
            }
            .sorted {
                if $0.completedAt != $1.completedAt { return $0.completedAt > $1.completedAt }
                return $0.id.uuidString > $1.id.uuidString
            }
    }

    static func displayName(for record: CompletionRecord) -> String {
        record.completedBy?.name ?? record.completedByName ?? "未知成员"
    }

    static func recreationDraft(for record: CompletionRecord) -> TemporaryTaskDraft? {
        guard let task = record.task else { return nil }
        return TemporaryTaskDraft(title: task.title, score: task.score)
    }

    private static func matchesMember(_ record: CompletionRecord, filter: HistoryMemberFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case let .member(id):
            return record.completedBy?.id == id
        case let .historicalName(name):
            return record.completedBy == nil && displayName(for: record) == name
        }
    }

    private static func contains(_ date: Date, in interval: DateInterval?) -> Bool {
        guard let interval else { return true }
        return date >= interval.start && date < interval.end
    }
}
