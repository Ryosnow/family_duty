import Foundation
import SwiftData

struct TaskGenerationService {
    let context: ModelContext
    let scheduler: RotationScheduler
    let calendar: Calendar

    init(context: ModelContext, scheduler: RotationScheduler = RotationScheduler(), calendar: Calendar = .current) {
        self.context = context
        self.scheduler = scheduler
        self.calendar = calendar
    }

    func ensureTasks(for rules: [ChoreRule], through endDate: Date) throws {
        let today = calendar.startOfDay(for: .now)
        for rule in rules where rule.isEnabled {
            var date = nextOccurrence(of: rule.weekday, onOrAfter: today)
            while date <= endDate {
                let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
                let alreadyExists = tasks.contains { task in
                    task.rule?.id == rule.id && task.scheduledDate == date
                }
                if !alreadyExists {
                    let task = ChoreTask(title: rule.title, scheduledDate: date, assignee: scheduler.assignee(for: rule, weekOf: date, calendar: calendar), rule: rule)
                    context.insert(task)
                }
                date = calendar.date(byAdding: .weekOfYear, value: 1, to: date)!
            }
        }
        try context.save()
    }

    private func nextOccurrence(of weekday: Int, onOrAfter date: Date) -> Date {
        let current = calendar.component(.weekday, from: date)
        return calendar.date(byAdding: .day, value: (weekday - current + 7) % 7, to: date)!
    }
}
