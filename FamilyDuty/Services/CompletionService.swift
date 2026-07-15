import Foundation
import SwiftData

enum CompletionError: Error, Equatable, LocalizedError {
    case taskNotPending

    var errorDescription: String? {
        switch self {
        case .taskNotPending:
            return "只有待处理任务可以完成"
        }
    }
}

@MainActor
struct CompletionService {
    let context: ModelContext
    let calendar: Calendar
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

    func complete(_ task: ChoreTask, by member: FamilyMember, at date: Date = .now) throws {
        guard task.status == .pending else { throw CompletionError.taskNotPending }
        let previousStatus = task.status
        let record = CompletionRecord(task: task, completedBy: member, completedAt: date, calendar: calendar)
        task.status = .completed
        context.insert(record)
        do {
            try saver(context)
        } catch {
            task.status = previousStatus
            context.delete(record)
            throw error
        }
    }
}
