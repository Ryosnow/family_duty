import Foundation

enum DashboardViewModel {
    static func pendingTasks(from tasks: [ChoreTask]) -> [ChoreTask] {
        tasks.filter { $0.status == .pending }.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    static func todayTasks(
        from tasks: [ChoreTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ChoreTask] {
        pendingTasks(from: tasks).filter {
            !$0.isTemporary && calendar.isDate($0.scheduledDate, inSameDayAs: now)
        }
    }

    static func todayProgress(
        from tasks: [ChoreTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (completed: Int, total: Int) {
        let activeTasks = tasks.filter {
            $0.status != .cancelled && calendar.isDate($0.scheduledDate, inSameDayAs: now)
        }
        return (
            completed: activeTasks.count(where: { $0.status == .completed }),
            total: activeTasks.count
        )
    }

    static func laterThisWeekTasks(
        from tasks: [ChoreTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ChoreTask] {
        let today = calendar.startOfDay(for: now)
        let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? today
        return pendingTasks(from: tasks).filter {
            !$0.isTemporary && $0.scheduledDate >= calendar.date(byAdding: .day, value: 1, to: today)! && $0.scheduledDate < endOfWeek
        }
    }

    static func overdueTasks(
        from tasks: [ChoreTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ChoreTask] {
        pendingTasks(from: tasks)
            .filter { TaskDeadlineService.isOverdue($0, now: now, calendar: calendar) }
            .sorted {
                let firstDeadline = TaskDeadlineService.effectiveDeadline(for: $0, calendar: calendar)
                let secondDeadline = TaskDeadlineService.effectiveDeadline(for: $1, calendar: calendar)
                if firstDeadline != secondDeadline { return firstDeadline < secondDeadline }
                return $0.scheduledDate < $1.scheduledDate
            }
    }

    static func temporaryTasks(
        from tasks: [ChoreTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ChoreTask] {
        pendingTasks(from: tasks)
            .filter(\.isTemporary)
            .filter { !TaskDeadlineService.isOverdue($0, now: now, calendar: calendar) }
    }

    static func accessibilityLabel(
        for task: ChoreTask,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let assignee = task.assignee?.name ?? "待领取"
        let source = task.isTemporary ? "临时任务" : "固定轮班"
        let overdue = TaskDeadlineService.isOverdue(task, now: now, calendar: calendar) ? "，已逾期" : ""
        return "\(task.title)，负责人\(assignee)，\(source)\(overdue)"
    }
}
