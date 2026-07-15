import Foundation

struct MemberWorkloadSummary: Equatable, Identifiable {
    let memberID: UUID?
    let memberName: String
    let completedCount: Int
    let totalScore: Int

    var id: String {
        memberID?.uuidString ?? "deleted-\(memberName)"
    }
}

struct WorkloadDataPoint: Equatable, Identifiable {
    let date: Date
    let memberID: UUID?
    let memberName: String
    let taskCount: Int
    let totalScore: Int

    var id: String {
        "\(date.timeIntervalSinceReferenceDate)-\(memberID?.uuidString ?? memberName)"
    }
}

enum ScoreReportViewModel {
    static func dateInterval(for period: ReportPeriod, calendar: Calendar) -> DateInterval? {
        period.dateInterval(calendar: calendar)
    }

    static func latestRecords(from records: [CompletionRecord]) -> [CompletionRecord] {
        var latestByTaskID: [UUID: CompletionRecord] = [:]
        var recordsWithoutTask: [CompletionRecord] = []

        for record in records {
            guard let taskID = record.task?.id else {
                recordsWithoutTask.append(record)
                continue
            }
            if let existing = latestByTaskID[taskID] {
                if existing.completedAt > record.completedAt {
                    continue
                }
                if existing.completedAt == record.completedAt && existing.id.uuidString >= record.id.uuidString {
                    continue
                }
            }
            latestByTaskID[taskID] = record
        }

        return (Array(latestByTaskID.values) + recordsWithoutTask)
            .sorted {
                if $0.completedAt != $1.completedAt { return $0.completedAt < $1.completedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    static func summaries(
        for period: ReportPeriod,
        members: [FamilyMember],
        records: [CompletionRecord],
        calendar: Calendar
    ) -> [MemberWorkloadSummary] {
        let interval = period.dateInterval(calendar: calendar)
        var accumulators = members.reduce(into: [WorkloadKey: Accumulator]()) { result, member in
            result[.member(member.id)] = Accumulator(memberID: member.id, memberName: member.name, sortOrder: member.sortOrder)
        }

        for record in latestRecords(from: records) where contains(record.workDate, in: interval) {
            let key = key(for: record)
            if accumulators[key] == nil {
                accumulators[key] = Accumulator(memberID: record.completedBy?.id, memberName: displayName(for: record), sortOrder: Int.max)
            }
            accumulators[key]?.completedCount += 1
            accumulators[key]?.totalScore += record.score
        }

        return accumulators.values
            .sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.memberName < $1.memberName
            }
            .map { MemberWorkloadSummary(memberID: $0.memberID, memberName: $0.memberName, completedCount: $0.completedCount, totalScore: $0.totalScore) }
    }

    static func dailyDataPoints(
        for period: ReportPeriod,
        records: [CompletionRecord],
        calendar: Calendar
    ) -> [WorkloadDataPoint] {
        let interval = period.dateInterval(calendar: calendar)
        var accumulators: [DataPointKey: Accumulator] = [:]

        for record in latestRecords(from: records) where contains(record.workDate, in: interval) {
            let date = calendar.startOfDay(for: record.workDate)
            let key = DataPointKey(date: date, workloadKey: key(for: record))
            if accumulators[key] == nil {
                accumulators[key] = Accumulator(memberID: record.completedBy?.id, memberName: displayName(for: record), sortOrder: Int.max)
            }
            accumulators[key]?.completedCount += 1
            accumulators[key]?.totalScore += record.score
        }

        return accumulators
            .map { key, value in
                WorkloadDataPoint(date: key.date, memberID: value.memberID, memberName: value.memberName, taskCount: value.completedCount, totalScore: value.totalScore)
            }
            .sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.memberName < $1.memberName
            }
    }

    private static func displayName(for record: CompletionRecord) -> String {
        record.completedBy?.name ?? record.completedByName ?? "未知成员"
    }

    private static func contains(_ date: Date, in interval: DateInterval?) -> Bool {
        guard let interval else { return false }
        return date >= interval.start && date < interval.end
    }

    private static func key(for record: CompletionRecord) -> WorkloadKey {
        if let memberID = record.completedBy?.id { return .member(memberID) }
        return .deleted(displayName(for: record))
    }

    private enum WorkloadKey: Hashable {
        case member(UUID)
        case deleted(String)
    }

    private struct DataPointKey: Hashable {
        let date: Date
        let workloadKey: WorkloadKey
    }

    private struct Accumulator {
        let memberID: UUID?
        let memberName: String
        let sortOrder: Int
        var completedCount = 0
        var totalScore = 0
    }
}
