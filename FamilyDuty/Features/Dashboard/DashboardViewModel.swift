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

    static func temporaryTasks(from tasks: [ChoreTask]) -> [ChoreTask] {
        pendingTasks(from: tasks).filter(\.isTemporary)
    }

    static func accessibilityLabel(for task: ChoreTask) -> String {
        let assignee = task.assignee?.name ?? "待领取"
        let source = task.isTemporary ? "临时任务" : "固定轮班"
        return "\(task.title)，负责人\(assignee)，\(source)"
    }
}
