import Foundation
import SwiftData

@Model
final class ChoreTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var scheduledDate: Date
    var sourceScheduledDate: Date?
    var deadline: Date?
    var score: Int = 1
    var isTemporary: Bool
    var isOneOffOverride: Bool = false
    var statusRaw: String
    var adjustmentNote: String?
    @Relationship(deleteRule: .nullify) var assignee: FamilyMember?
    @Relationship(deleteRule: .nullify) var rule: ChoreRule?

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        scheduledDate: Date,
        sourceScheduledDate: Date? = nil,
        deadline: Date? = nil,
        score: Int = 1,
        assignee: FamilyMember? = nil,
        rule: ChoreRule? = nil,
        isTemporary: Bool = false,
        isOneOffOverride: Bool = false,
        status: TaskStatus = .pending,
        adjustmentNote: String? = nil
    ) {
        self.id = id
        self.title = title
        self.scheduledDate = scheduledDate
        self.sourceScheduledDate = sourceScheduledDate
        self.deadline = deadline
        self.score = score
        self.assignee = assignee
        self.rule = rule
        self.isTemporary = isTemporary
        self.isOneOffOverride = isOneOffOverride
        self.statusRaw = status.rawValue
        self.adjustmentNote = adjustmentNote
    }
}
