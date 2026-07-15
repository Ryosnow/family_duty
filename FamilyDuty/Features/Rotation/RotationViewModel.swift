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
    let now: Date
    private let saver: (ModelContext) throws -> Void

    init(
        context: ModelContext,
        calendar: Calendar = .current,
        now: Date = .now,
        saver: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.calendar = calendar
        self.now = now
        self.saver = saver
    }

    @discardableResult
    func saveRule(
        existingRule: ChoreRule? = nil,
        title: String,
        weekday: Int,
        startOfRotationWeek: Date,
        participants: [FamilyMember],
        isEnabled: Bool,
        score: Int = 1,
        generateThrough endDate: Date
    ) throws -> ChoreRule {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw RotationRuleValidationError.missingTitle }
        guard !participants.isEmpty else { throw RotationRuleValidationError.missingParticipants }
        try ScoreValidationService.validate(score: score)

        let rule: ChoreRule
        let previousRuleState: RuleState?
        var deletedTasks: [ChoreTask] = []
        if let existingRule {
            previousRuleState = RuleState(rule: existingRule)
            let today = calendar.startOfDay(for: now)
            let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
            for task in tasks where
                task.rule?.id == existingRule.id &&
                task.scheduledDate >= today &&
                task.status == .pending &&
                task.adjustmentNote == nil {
                deletedTasks.append(task)
                context.delete(task)
            }
            rule = existingRule
            rule.title = trimmedTitle
            rule.weekday = weekday
            rule.startOfRotationWeek = startOfRotationWeek
            rule.participants = participants
            rule.participantOrder = participants.map(\.id)
            rule.isEnabled = isEnabled
            rule.score = score
        } else {
            previousRuleState = nil
            rule = ChoreRule(
                title: trimmedTitle,
                weekday: weekday,
                startOfRotationWeek: startOfRotationWeek,
                participants: participants,
                isEnabled: isEnabled,
                score: score
            )
            context.insert(rule)
        }

        do {
            try TaskGenerationService(context: context, calendar: calendar, now: now, saver: saver)
                .ensureTasks(for: [rule], through: endDate, save: false)
            try saver(context)
        } catch {
            context.rollback()
            if let previousRuleState {
                previousRuleState.restore(on: rule)
                for task in deletedTasks { context.insert(task) }
            } else {
                context.delete(rule)
            }
            throw error
        }
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
        deadline: Date? = nil,
        score: Int? = nil,
        cancellationReason: String?
    ) throws {
        let previousTaskState = TaskState(task: task)
        if cancellationReason == nil, let score { try ScoreValidationService.validate(score: score) }
        if cancellationReason == nil {
            try TaskDeadlineService.validate(deadline: deadline, scheduledDate: scheduledDate, calendar: calendar)
        }

        if let cancellationReason {
            task.status = .cancelled
            task.adjustmentNote = cancellationReason.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            var changes: [String] = []
            if task.assignee?.id != assignee?.id { changes.append("改派") }
            if !calendar.isDate(task.scheduledDate, inSameDayAs: scheduledDate) { changes.append("改期") }
            task.assignee = assignee
            task.scheduledDate = scheduledDate
            task.deadline = TaskDeadlineService.normalized(deadline: deadline, calendar: calendar)
            if let score { task.score = score }
            task.status = .pending
            if !changes.isEmpty { task.adjustmentNote = changes.joined(separator: "、") }
        }
        do {
            try saver(context)
        } catch {
            context.rollback()
            previousTaskState.restore(on: task)
            throw error
        }
    }

    private struct RuleState {
        let title: String
        let weekday: Int
        let startOfRotationWeek: Date
        let isEnabled: Bool
        let score: Int
        let participantOrder: [UUID]
        let participants: [FamilyMember]

        init(rule: ChoreRule) {
            title = rule.title
            weekday = rule.weekday
            startOfRotationWeek = rule.startOfRotationWeek
            isEnabled = rule.isEnabled
            score = rule.score
            participantOrder = rule.participantOrder
            participants = rule.participants
        }

        func restore(on rule: ChoreRule) {
            rule.title = title
            rule.weekday = weekday
            rule.startOfRotationWeek = startOfRotationWeek
            rule.isEnabled = isEnabled
            rule.score = score
            rule.participantOrder = participantOrder
            rule.participants = participants
        }
    }

    private struct TaskState {
        let assignee: FamilyMember?
        let scheduledDate: Date
        let deadline: Date?
        let score: Int
        let status: TaskStatus
        let adjustmentNote: String?

        init(task: ChoreTask) {
            assignee = task.assignee
            scheduledDate = task.scheduledDate
            deadline = task.deadline
            score = task.score
            status = task.status
            adjustmentNote = task.adjustmentNote
        }

        func restore(on task: ChoreTask) {
            task.assignee = assignee
            task.scheduledDate = scheduledDate
            task.deadline = deadline
            task.score = score
            task.status = status
            task.adjustmentNote = adjustmentNote
        }
    }
}
