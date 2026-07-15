import Foundation
import SwiftData

@Model
final class CompletionRecord {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var workDate: Date = Foundation.Date.now
    var score: Int = 1
    var completedByName: String?
    var task: ChoreTask?
    var completedBy: FamilyMember?

    init(id: UUID = UUID(), task: ChoreTask, completedBy: FamilyMember, completedAt: Date = .now, calendar: Calendar = .current) {
        self.id = id
        self.task = task
        self.completedBy = completedBy
        self.completedByName = completedBy.name
        self.completedAt = completedAt
        self.workDate = calendar.startOfDay(for: task.scheduledDate)
        self.score = task.score
    }
}
