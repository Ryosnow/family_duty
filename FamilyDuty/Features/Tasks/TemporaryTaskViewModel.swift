import Foundation
import SwiftData

enum TemporaryTaskValidationError: Error, Equatable, LocalizedError {
    case missingTitle
    case alreadyAssigned
    case taskNotPending

    var errorDescription: String? {
        switch self {
        case .missingTitle: "请输入任务名称"
        case .alreadyAssigned: "这项任务已经有人负责"
        case .taskNotPending: "只有待处理任务可以领取"
        }
    }
}

@MainActor
struct TemporaryTaskViewModel {
    let context: ModelContext
    var calendar: Calendar
    private let saver: (ModelContext) throws -> Void

    init(
        context: ModelContext,
        calendar: Calendar = .current,
        saver: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.calendar = calendar
        self.saver = saver
    }

    @discardableResult
    func createTask(title: String, scheduledDate: Date, deadline: Date? = nil, score: Int = 1, assignee: FamilyMember?) throws -> ChoreTask {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw TemporaryTaskValidationError.missingTitle }
        try ScoreValidationService.validate(score: score)
        try TaskDeadlineService.validate(deadline: deadline, scheduledDate: scheduledDate, calendar: calendar)
        let task = ChoreTask(
            title: trimmedTitle,
            scheduledDate: scheduledDate,
            deadline: TaskDeadlineService.normalized(deadline: deadline, calendar: calendar),
            score: score,
            assignee: assignee,
            rule: nil,
            isTemporary: true
        )
        context.insert(task)
        do {
            try saver(context)
        } catch {
            context.rollback()
            throw error
        }
        return task
    }

    func claim(_ task: ChoreTask, by member: FamilyMember) throws {
        guard task.status == .pending else { throw TemporaryTaskValidationError.taskNotPending }
        guard task.assignee == nil else { throw TemporaryTaskValidationError.alreadyAssigned }
        let previousAssignee = task.assignee
        task.assignee = member
        do {
            try saver(context)
        } catch {
            context.rollback()
            task.assignee = previousAssignee
            throw error
        }
    }
}
