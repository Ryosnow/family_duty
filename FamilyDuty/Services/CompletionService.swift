import Foundation
import SwiftData

@MainActor
struct CompletionService {
    let context: ModelContext
    private let saver: (ModelContext) throws -> Void

    init(
        context: ModelContext,
        saver: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.saver = saver
    }

    func complete(_ task: ChoreTask, by member: FamilyMember, at date: Date = .now) throws {
        let previousStatus = task.status
        let record = CompletionRecord(task: task, completedBy: member, completedAt: date)
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
