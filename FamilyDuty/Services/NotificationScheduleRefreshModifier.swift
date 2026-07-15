import SwiftData
import SwiftUI

private struct NotificationScheduleRefreshModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var tasks: [ChoreTask]
    @AppStorage("notifications.enabled") private var isEnabled = false
    @AppStorage("notifications.dailyHour") private var dailyHour = 8
    @AppStorage("notifications.overdueHour") private var overdueHour = 19
    @State private var errorMessage: String?
    @State private var currentDay = Calendar.current.startOfDay(for: .now)

    private var taskSignature: String {
        tasks
            .map {
                [
                    $0.id.uuidString,
                    $0.title,
                    $0.statusRaw,
                    String($0.scheduledDate.timeIntervalSinceReferenceDate),
                    String($0.deadline?.timeIntervalSinceReferenceDate ?? 0),
                    $0.assignee?.id.uuidString ?? "unassigned"
                ].joined(separator: "|")
            }
            .sorted()
            .joined(separator: ";")
    }

    private var refreshSignature: String {
        "\(taskSignature)#\(isEnabled)#\(dailyHour)#\(overdueHour)#\(currentDay.timeIntervalSinceReferenceDate)"
    }

    func body(content: Content) -> some View {
        content
            .task(id: refreshSignature) { await refresh() }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                currentDay = Calendar.current.startOfDay(for: .now)
            }
            .alert("无法更新提醒", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
    }

    private func refresh() async {
        do {
            try await NotificationScheduler().refreshSchedule(
                for: tasks,
                settings: NotificationSettings(
                    isEnabled: isEnabled,
                    dailySummaryHour: dailyHour,
                    overdueHour: overdueHour
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension View {
    func refreshNotificationScheduleWhenTasksChange() -> some View {
        modifier(NotificationScheduleRefreshModifier())
    }
}
