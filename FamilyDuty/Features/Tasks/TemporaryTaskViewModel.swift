import Foundation
import SwiftData

enum TemporaryTaskValidationError: Error, Equatable, LocalizedError {
    case missingTitle
    case alreadyAssigned

    var errorDescription: String? {
        switch self {
        case .missingTitle: "请输入任务名称"
        case .alreadyAssigned: "这项任务已经有人负责"
        }
    }
}

@MainActor
struct TemporaryTaskViewModel {
    let context: ModelContext

    @discardableResult
    func createTask(title: String, scheduledDate: Date, assignee: FamilyMember?) throws -> ChoreTask {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw TemporaryTaskValidationError.missingTitle }
        let task = ChoreTask(
            title: trimmedTitle,
            scheduledDate: scheduledDate,
            assignee: assignee,
            rule: nil,
            isTemporary: true
        )
        context.insert(task)
        try context.save()
        return task
    }

    func claim(_ task: ChoreTask, by member: FamilyMember) throws {
        guard task.assignee == nil else { throw TemporaryTaskValidationError.alreadyAssigned }
        task.assignee = member
        try context.save()
    }
}
