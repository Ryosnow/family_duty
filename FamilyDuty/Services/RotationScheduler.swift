import Foundation

struct RotationScheduler {
    func assignee(for rule: ChoreRule, weekOf date: Date, calendar: Calendar) -> FamilyMember? {
        let participants = rule.orderedParticipants
        guard rule.isEnabled, !participants.isEmpty else { return nil }
        let start = calendar.dateInterval(of: .weekOfYear, for: rule.startOfRotationWeek)?.start ?? rule.startOfRotationWeek
        let target = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let weeks = calendar.dateComponents([.weekOfYear], from: start, to: target).weekOfYear ?? 0
        let index = ((weeks % participants.count) + participants.count) % participants.count
        return participants[index]
    }
}
