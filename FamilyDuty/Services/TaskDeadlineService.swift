import Foundation

enum TaskDeadlineValidationError: Error, Equatable, LocalizedError {
    case beforeScheduledDate

    var errorDescription: String? {
        switch self {
        case .beforeScheduledDate:
            return "Deadline 不能早于任务日期"
        }
    }
}

enum TaskDeadlineService {
    static func effectiveDeadline(for task: ChoreTask, calendar: Calendar) -> Date {
        calendar.startOfDay(for: task.deadline ?? task.scheduledDate)
    }

    static func isOverdue(_ task: ChoreTask, now: Date, calendar: Calendar) -> Bool {
        guard task.status == .pending else { return false }
        return calendar.startOfDay(for: now) > effectiveDeadline(for: task, calendar: calendar)
    }

    static func validate(deadline: Date?, scheduledDate: Date, calendar: Calendar) throws {
        guard let deadline else { return }
        guard calendar.startOfDay(for: deadline) >= calendar.startOfDay(for: scheduledDate) else {
            throw TaskDeadlineValidationError.beforeScheduledDate
        }
    }

    static func normalized(deadline: Date?, calendar: Calendar) -> Date? {
        deadline.map { calendar.startOfDay(for: $0) }
    }
}
