import Foundation

struct NotificationSettings: Equatable {
    var isEnabled: Bool
    var dailySummaryHour: Int
    var overdueHour: Int
}

struct NotificationScheduler {
    static let dailySummaryIdentifier = "family-duty.daily-summary"
    static let overdueIdentifier = "family-duty.overdue-summary"

    let client: NotificationCenterClient
    var calendar: Calendar

    init(client: NotificationCenterClient = SystemNotificationCenterClient(), calendar: Calendar = .current) {
        self.client = client
        self.calendar = calendar
    }

    func refreshSchedule(
        for tasks: [ChoreTask],
        settings: NotificationSettings,
        now: Date = .now
    ) async throws {
        let pendingIdentifiers = await client.pendingRequestIdentifiers()
        let managedIdentifiers = pendingIdentifiers.filter {
            $0 == Self.dailySummaryIdentifier || $0 == Self.overdueIdentifier
        }
        client.removePendingRequests(withIdentifiers: managedIdentifiers)
        guard settings.isEnabled else { return }

        let today = calendar.startOfDay(for: now)
        let todaysTasks = tasks.filter {
            $0.status == .pending && calendar.isDate($0.scheduledDate, inSameDayAs: today)
        }
        if !todaysTasks.isEmpty {
            try await client.add(
                identifier: Self.dailySummaryIdentifier,
                title: "今日家庭值日",
                body: todaysTasks.map(\.title).joined(separator: "、"),
                dateComponents: DateComponents(hour: settings.dailySummaryHour, minute: 0)
            )
        }

        let overdueTasks = tasks.filter {
            TaskDeadlineService.isOverdue($0, now: now, calendar: calendar)
        }
        if !overdueTasks.isEmpty {
            try await client.add(
                identifier: Self.overdueIdentifier,
                title: "还有逾期值日",
                body: overdueTasks.map(\.title).joined(separator: "、"),
                dateComponents: DateComponents(hour: settings.overdueHour, minute: 0)
            )
        }
    }
}
