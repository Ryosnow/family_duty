import Foundation

struct NotificationSettings: Equatable {
    var isEnabled: Bool
    var dailySummaryHour: Int
    var overdueHour: Int
}

struct NotificationScheduler {
    static let dailySummaryIdentifier = "family-duty.daily-summary"
    static let overdueIdentifier = "family-duty.overdue-summary"
    static let dailySummaryIdentifierPrefix = "\(dailySummaryIdentifier)."
    static let overdueIdentifierPrefix = "\(overdueIdentifier)."

    let client: NotificationCenterClient
    var calendar: Calendar
    let horizonDays: Int

    init(
        client: NotificationCenterClient = SystemNotificationCenterClient(),
        calendar: Calendar = .current,
        horizonDays: Int = 28
    ) {
        self.client = client
        self.calendar = calendar
        self.horizonDays = min(max(horizonDays, 0), 28)
    }

    func refreshSchedule(
        for tasks: [ChoreTask],
        settings: NotificationSettings,
        now: Date = .now
    ) async throws {
        let pendingIdentifiers = await client.pendingRequestIdentifiers()
        let managedIdentifiers = pendingIdentifiers.filter(Self.isManagedIdentifier)
        client.removePendingRequests(withIdentifiers: managedIdentifiers)
        guard settings.isEnabled else { return }

        let today = calendar.startOfDay(for: now)
        for dayOffset in 0...horizonDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let todaysTasks = tasks.filter {
                $0.status == .pending && calendar.isDate($0.scheduledDate, inSameDayAs: day)
            }
            try await schedule(
                tasks: todaysTasks,
                identifierPrefix: Self.dailySummaryIdentifierPrefix,
                title: "今日家庭值日",
                day: day,
                hour: settings.dailySummaryHour,
                now: now
            )

            let overdueTasks = tasks.filter {
                TaskDeadlineService.isOverdue($0, now: day, calendar: calendar)
            }
            try await schedule(
                tasks: overdueTasks,
                identifierPrefix: Self.overdueIdentifierPrefix,
                title: "还有逾期值日",
                day: day,
                hour: settings.overdueHour,
                now: now
            )
        }
    }

    private static func isManagedIdentifier(_ identifier: String) -> Bool {
        identifier == dailySummaryIdentifier ||
        identifier == overdueIdentifier ||
        identifier.hasPrefix(dailySummaryIdentifierPrefix) ||
        identifier.hasPrefix(overdueIdentifierPrefix)
    }

    private func schedule(
        tasks: [ChoreTask],
        identifierPrefix: String,
        title: String,
        day: Date,
        hour: Int,
        now: Date
    ) async throws {
        guard !tasks.isEmpty,
              let notificationDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
              notificationDate > now else {
            return
        }
        try await client.add(
            identifier: identifierPrefix + dateKey(for: day),
            title: title,
            body: tasks.map(\.title).joined(separator: "、"),
            dateComponents: calendar.dateComponents(
                [.calendar, .timeZone, .year, .month, .day, .hour, .minute],
                from: notificationDate
            ),
            repeats: false
        )
    }

    private func dateKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
