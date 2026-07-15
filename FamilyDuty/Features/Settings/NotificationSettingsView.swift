import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct NotificationSettingsView: View {
    @Query private var tasks: [ChoreTask]
    @AppStorage("notifications.enabled") private var isEnabled = false
    @AppStorage("notifications.dailyHour") private var dailyHour = 8
    @AppStorage("notifications.overdueHour") private var overdueHour = 19
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var errorMessage: String?
    @State private var refreshID = UUID()

    var body: some View {
        Form {
            Section("提醒") {
                Toggle("启用本地提醒", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, enabled in
                        Task { await enabledChanged(enabled) }
                    }
                Picker("每日汇总时间", selection: $dailyHour) {
                    ForEach(0..<24, id: \.self) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                }
                Picker("逾期提醒时间", selection: $overdueHour) {
                    ForEach(0..<24, id: \.self) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                }
            }

            if let permissionMessage = NotificationPermissionPresentation.message(for: authorizationStatus) {
                Section("通知权限") {
                    Text(permissionMessage)
                    Button("打开系统设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
        .navigationTitle("通知设置")
        .task { authorizationStatus = await NotificationAuthorizationService().status() }
        .task(id: refreshID) { await refresh() }
        .onChange(of: dailyHour) { _, _ in refreshID = UUID() }
        .onChange(of: overdueHour) { _, _ in refreshID = UUID() }
        .alert("无法更新提醒", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private func enabledChanged(_ enabled: Bool) async {
        guard enabled else {
            refreshID = UUID()
            return
        }

        do {
            if authorizationStatus == .notDetermined {
                _ = try await NotificationAuthorizationService().requestAuthorization()
                authorizationStatus = await NotificationAuthorizationService().status()
            }
            guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
                isEnabled = false
                errorMessage = "系统通知权限未开启，请在系统设置中允许通知。"
                return
            }
        } catch {
            isEnabled = false
            errorMessage = error.localizedDescription
            return
        }
        refreshID = UUID()
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
