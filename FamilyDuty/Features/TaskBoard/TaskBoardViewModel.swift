import Foundation

struct TaskBoardSections {
    let pending: [ChoreTask]
    let completed: [ChoreTask]
    let cancelled: [ChoreTask]
}

enum TaskBoardViewModel {
    static func todayTasks(
        from tasks: [ChoreTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ChoreTask] {
        tasks.filter { calendar.isDate($0.scheduledDate, inSameDayAs: now) }
    }

    static func sections(
        from tasks: [ChoreTask],
        records: [CompletionRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TaskBoardSections {
        let today = todayTasks(from: tasks, now: now, calendar: calendar)

        let pending = today
            .filter { $0.status == .pending }
            .sorted { first, second in
                let firstDeadline = TaskDeadlineService.effectiveDeadline(for: first, calendar: calendar)
                let secondDeadline = TaskDeadlineService.effectiveDeadline(for: second, calendar: calendar)
                if firstDeadline != secondDeadline {
                    return firstDeadline < secondDeadline
                }
                if first.scheduledDate != second.scheduledDate {
                    return first.scheduledDate < second.scheduledDate
                }
                return first.title < second.title
            }

        let completed = today
            .filter { $0.status == .completed }
            .sorted { first, second in
                let firstCompletion = latestCompletionRecord(for: first, from: records)?.completedAt ?? .distantPast
                let secondCompletion = latestCompletionRecord(for: second, from: records)?.completedAt ?? .distantPast
                if firstCompletion != secondCompletion {
                    return firstCompletion > secondCompletion
                }
                return first.title < second.title
            }

        let cancelled = today
            .filter { $0.status == .cancelled }
            .sorted { first, second in
                if first.scheduledDate != second.scheduledDate {
                    return first.scheduledDate < second.scheduledDate
                }
                return first.title < second.title
            }

        return TaskBoardSections(pending: pending, completed: completed, cancelled: cancelled)
    }

    static func latestCompletionRecord(
        for task: ChoreTask,
        from records: [CompletionRecord]
    ) -> CompletionRecord? {
        records
            .filter { $0.task?.id == task.id }
            .max { $0.completedAt < $1.completedAt }
    }
}
