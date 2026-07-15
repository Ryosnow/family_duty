import Foundation
import SwiftData

enum CompletionError: Error, Equatable, LocalizedError {
    case taskNotPending
    case taskNotCompleted
    case missingCompletionRecord

    var errorDescription: String? {
        switch self {
        case .taskNotPending:
            return "只有待处理任务可以完成"
        case .taskNotCompleted:
            return "只有已完成任务可以撤销完成"
        case .missingCompletionRecord:
            return "找不到这项任务的完成记录"
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

    func undoCompletion(_ task: ChoreTask) throws {
        guard task.status == .completed else { throw CompletionError.taskNotCompleted }
        let records = try context.fetch(FetchDescriptor<CompletionRecord>())
        guard let latestRecord = records
            .filter({ $0.task?.id == task.id })
            .max(by: { $0.completedAt < $1.completedAt }) else {
            throw CompletionError.missingCompletionRecord
        }

        let previousStatus = task.status
        task.status = .pending
        context.delete(latestRecord)
        do {
            try saver(context)
        } catch {
            context.rollback()
            task.status = previousStatus
            throw error
        }
    }
}
