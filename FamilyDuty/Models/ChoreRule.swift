import Foundation
import SwiftData

@Model
final class ChoreRule {
    @Attribute(.unique) var id: UUID
    var title: String
    var weekday: Int
    var startOfRotationWeek: Date
    var isEnabled: Bool
    var participantOrder: [UUID]
    @Relationship var participants: [FamilyMember]

    var orderedParticipants: [FamilyMember] {
        let membersByID = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        return participantOrder.compactMap { membersByID[$0] }
    }

    init(id: UUID = UUID(), title: String, weekday: Int, startOfRotationWeek: Date, participants: [FamilyMember], isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.weekday = weekday
        self.startOfRotationWeek = startOfRotationWeek
        self.participants = participants
        self.participantOrder = participants.map(\.id)
        self.isEnabled = isEnabled
    }
}
