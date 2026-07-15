import Foundation
import SwiftData

enum MemberDeletionBlocker: Equatable {
    case rule(String)
    case pendingTask(String)
    case completionHistory(String)

    var message: String {
        switch self {
        case .rule(let title): "固定轮班“\(title)”仍包含该成员"
        case .pendingTask(let title): "待办“\(title)”仍由该成员负责"
        case .completionHistory(let title): "完成记录“\(title)”引用了该成员"
        }
    }
}

enum MemberDeletionError: Error, LocalizedError {
    case blocked([MemberDeletionBlocker])

    var errorDescription: String? {
        switch self {
        case .blocked(let blockers): blockers.map(\.message).joined(separator: "\n")
        }
    }
}

@MainActor
struct MemberDeletionService {
    let context: ModelContext

    func blockers(for member: FamilyMember) throws -> [MemberDeletionBlocker] {
        var result: [MemberDeletionBlocker] = []
        let rules = try context.fetch(FetchDescriptor<ChoreRule>())
        for rule in rules where rule.participants.contains(where: { $0.id == member.id }) {
            result.append(.rule(rule.title))
        }

        let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
        for task in tasks where task.assignee?.id == member.id && task.status == .pending {
            result.append(.pendingTask(task.title))
        }

        let records = try context.fetch(FetchDescriptor<CompletionRecord>())
        for record in records where record.completedBy?.id == member.id {
            result.append(.completionHistory(record.task?.title ?? "值日"))
        }
        return result
    }

    func delete(_ member: FamilyMember) throws {
        let blockers = try blockers(for: member)
        guard blockers.isEmpty else { throw MemberDeletionError.blocked(blockers) }
        context.delete(member)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
