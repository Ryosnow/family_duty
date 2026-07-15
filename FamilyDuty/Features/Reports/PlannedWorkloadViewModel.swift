import Foundation

struct PlannedWorkloadSummary: Equatable, Identifiable {
    let memberID: UUID
    let memberName: String
    let assignedCount: Int
    let plannedScore: Int

    var id: UUID { memberID }
}

enum PlannedWorkloadViewModel {
    static func weeklySummaries(
        for anchorDate: Date,
        tasks: [ChoreTask],
        members: [FamilyMember],
        calendar: Calendar
    ) -> [PlannedWorkloadSummary] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: anchorDate) else {
            return []
        }

        var accumulators = Dictionary(uniqueKeysWithValues: members.map {
            ($0.id, Accumulator(memberID: $0.id, memberName: $0.name, sortOrder: $0.sortOrder))
        })
        let memberIDs = Set(members.map(\.id))

        for task in tasks {
            guard let assignee = task.assignee,
                  memberIDs.contains(assignee.id),
                  task.scheduledDate >= interval.start,
                  task.scheduledDate < interval.end else {
                continue
            }

            accumulators[assignee.id]?.assignedCount += 1
            accumulators[assignee.id]?.plannedScore += task.score
        }

        return accumulators.values
            .sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.memberName < $1.memberName
            }
            .map {
                PlannedWorkloadSummary(
                    memberID: $0.memberID,
                    memberName: $0.memberName,
                    assignedCount: $0.assignedCount,
                    plannedScore: $0.plannedScore
                )
            }
    }

    private struct Accumulator {
        let memberID: UUID
        let memberName: String
        let sortOrder: Int
        var assignedCount = 0
        var plannedScore = 0
    }
}
