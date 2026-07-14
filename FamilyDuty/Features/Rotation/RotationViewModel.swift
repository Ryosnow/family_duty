import Foundation
import SwiftData
import SwiftUI

enum RotationRuleValidationError: Error, Equatable, LocalizedError {
    case missingTitle
    case missingParticipants

    var errorDescription: String? {
        switch self {
        case .missingTitle: "请输入任务名称"
        case .missingParticipants: "请至少选择一名家庭成员"
        }
    }
}

@MainActor
struct RotationViewModel {
    let context: ModelContext
    var calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    @discardableResult
    func saveRule(
        existingRule: ChoreRule? = nil,
        title: String,
        weekday: Int,
        startOfRotationWeek: Date,
        participants: [FamilyMember],
        isEnabled: Bool,
        generateThrough endDate: Date
    ) throws -> ChoreRule {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw RotationRuleValidationError.missingTitle }
        guard !participants.isEmpty else { throw RotationRuleValidationError.missingParticipants }

        let rule: ChoreRule
        if let existingRule {
            let today = calendar.startOfDay(for: .now)
            let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
            for task in tasks where
                task.rule?.id == existingRule.id &&
                task.scheduledDate >= today &&
                task.status == .pending &&
                task.adjustmentNote == nil {
                context.delete(task)
            }
            rule = existingRule
            rule.title = trimmedTitle
            rule.weekday = weekday
            rule.startOfRotationWeek = startOfRotationWeek
            rule.participants = participants
            rule.participantOrder = participants.map(\.id)
            rule.isEnabled = isEnabled
        } else {
            rule = ChoreRule(
                title: trimmedTitle,
                weekday: weekday,
                startOfRotationWeek: startOfRotationWeek,
                participants: participants,
                isEnabled: isEnabled
            )
            context.insert(rule)
        }

        try context.save()
        try TaskGenerationService(context: context, calendar: calendar)
            .ensureTasks(for: [rule], through: endDate)
        return rule
    }

    func moving(
        _ participants: [FamilyMember],
        fromOffsets: IndexSet,
        toOffset: Int
    ) -> [FamilyMember] {
        var result = participants
        result.move(fromOffsets: fromOffsets, toOffset: toOffset)
        return result
    }

    func adjust(
        _ task: ChoreTask,
        assignee: FamilyMember?,
        scheduledDate: Date,
        cancellationReason: String?
    ) throws {
        if let cancellationReason {
            task.status = .cancelled
            task.adjustmentNote = cancellationReason.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            var changes: [String] = []
            if task.assignee?.id != assignee?.id { changes.append("改派") }
            if !calendar.isDate(task.scheduledDate, inSameDayAs: scheduledDate) { changes.append("改期") }
            task.assignee = assignee
            task.scheduledDate = scheduledDate
            task.status = .pending
            if !changes.isEmpty { task.adjustmentNote = changes.joined(separator: "、") }
        }
        try context.save()
    }
}
