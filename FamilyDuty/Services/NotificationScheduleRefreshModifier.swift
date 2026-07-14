import SwiftData
import SwiftUI

private struct NotificationScheduleRefreshModifier: ViewModifier {
    @Query private var tasks: [ChoreTask]
    @AppStorage("notifications.enabled") private var isEnabled = false
    @AppStorage("notifications.dailyHour") private var dailyHour = 8
    @AppStorage("notifications.overdueHour") private var overdueHour = 19

    private var taskSignature: String {
        tasks
            .map {
                [
                    $0.id.uuidString,
                    $0.title,
                    $0.statusRaw,
                    String($0.scheduledDate.timeIntervalSinceReferenceDate),
                    $0.assignee?.id.uuidString ?? "unassigned"
                ].joined(separator: "|")
            }
            .sorted()
            .joined(separator: ";")
    }

    private var refreshSignature: String {
        "\(taskSignature)#\(isEnabled)#\(dailyHour)#\(overdueHour)"
    }

    func body(content: Content) -> some View {
        content.onChange(of: refreshSignature, initial: true) { _, _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        try? await NotificationScheduler().refreshSchedule(
            for: tasks,
            settings: NotificationSettings(
                isEnabled: isEnabled,
                dailySummaryHour: dailyHour,
                overdueHour: overdueHour
            )
        )
    }
}

extension View {
    func refreshNotificationScheduleWhenTasksChange() -> some View {
        modifier(NotificationScheduleRefreshModifier())
    }
}
