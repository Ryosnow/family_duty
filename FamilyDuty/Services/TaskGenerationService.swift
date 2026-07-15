import Foundation
import SwiftData

enum TaskGenerationError: Error, Equatable, LocalizedError {
    case dateCalculationFailed

    var errorDescription: String? {
        switch self {
        case .dateCalculationFailed:
            return "无法计算值日日期"
        }
    }
}

struct TaskGenerationService {
    let context: ModelContext
    let scheduler: RotationScheduler
    let calendar: Calendar
    let now: Date
    private let saver: (ModelContext) throws -> Void

    init(
        context: ModelContext,
        scheduler: RotationScheduler = RotationScheduler(),
        calendar: Calendar = .current,
        now: Date = .now,
        saver: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.scheduler = scheduler
        self.calendar = calendar
        self.now = now
        self.saver = saver
    }

    func ensureTasks(for rules: [ChoreRule], through endDate: Date, save: Bool = true) throws {
        let today = calendar.startOfDay(for: now)
        var existingTaskKeys = Set<TaskGenerationKey>()
        for task in try context.fetch(FetchDescriptor<ChoreTask>()) {
            guard let ruleID = task.rule?.id else { continue }
            existingTaskKeys.insert(TaskGenerationKey(ruleID: ruleID, scheduledDate: task.scheduledDate))
        }

        for rule in rules where rule.isEnabled {
            var date = try nextOccurrence(of: rule.weekday, onOrAfter: today)
            while date <= endDate {
                let key = TaskGenerationKey(ruleID: rule.id, scheduledDate: date)
                if !existingTaskKeys.contains(key) {
                    let task = ChoreTask(title: rule.title, scheduledDate: date, score: rule.score, assignee: scheduler.assignee(for: rule, weekOf: date, calendar: calendar), rule: rule)
                    context.insert(task)
                    existingTaskKeys.insert(key)
                }
                guard let nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: date) else {
                    throw TaskGenerationError.dateCalculationFailed
                }
                date = nextDate
            }
        }
        if save {
            do {
                try saver(context)
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    private struct TaskGenerationKey: Hashable {
        let ruleID: UUID
        let scheduledDate: Date
    }

    private func nextOccurrence(of weekday: Int, onOrAfter date: Date) throws -> Date {
        let current = calendar.component(.weekday, from: date)
        guard let nextDate = calendar.date(byAdding: .day, value: (weekday - current + 7) % 7, to: date) else {
            throw TaskGenerationError.dateCalculationFailed
        }
        return nextDate
    }
}
