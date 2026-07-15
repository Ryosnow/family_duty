import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @Query private var members: [FamilyMember]

    var body: some View {
        Group {
            if members.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .task { seedUITestDataIfNeeded() }
    }

    private func seedUITestDataIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTesting"), members.isEmpty else { return }
        guard arguments.contains("-seedMember") || arguments.contains("-seedDashboardTask") || arguments.contains("-seedOverdueTask") || arguments.contains("-seedTaskBoard") else { return }
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let secondMember = FamilyMember(name: "小红", sortOrder: 1)
        context.insert(member)
        if arguments.contains("-seedTaskBoard") {
            context.insert(secondMember)
        }
        if arguments.contains("-seedDashboardTask") {
            context.insert(ChoreTask(title: "扫地", scheduledDate: .now, assignee: member))
        }
        if arguments.contains("-seedOverdueTask") {
            let scheduledDate = Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
            context.insert(ChoreTask(title: "逾期任务", scheduledDate: scheduledDate, assignee: member))
        }
        if arguments.contains("-seedTaskBoard") {
            let completedTask = ChoreTask(title: "面板已完成", scheduledDate: .now, score: 3, assignee: member)
            completedTask.status = .completed
            let secondCompletedTask = ChoreTask(title: "面板另一项已完成", scheduledDate: .now, score: 2, assignee: secondMember)
            secondCompletedTask.status = .completed
            let cancelledTask = ChoreTask(title: "面板已取消", scheduledDate: .now, assignee: member)
            cancelledTask.status = .cancelled
            cancelledTask.adjustmentNote = "本次由家人临时取消"
            let pendingTask = ChoreTask(title: "面板待处理", scheduledDate: .now, assignee: member)
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
            let tomorrowTask = ChoreTask(title: "面板明天", scheduledDate: tomorrow, assignee: member)
            context.insert(completedTask)
            context.insert(secondCompletedTask)
            context.insert(cancelledTask)
            context.insert(pendingTask)
            context.insert(tomorrowTask)
            context.insert(CompletionRecord(task: completedTask, completedBy: member, completedAt: .now))
            context.insert(CompletionRecord(task: secondCompletedTask, completedBy: secondMember, completedAt: .now))
        }
        do {
            try context.save()
        } catch {
            assertionFailure("无法保存 UI 测试种子数据：\(error.localizedDescription)")
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }

            TaskBoardView()
                .tabItem {
                    Label("任务面板", systemImage: "checklist")
                        .accessibilityIdentifier("task-board-tab")
                }

            ReportsView()
                .tabItem {
                    Label("报表", systemImage: "chart.bar.xaxis")
                        .accessibilityIdentifier("reports-tab")
                }

            RotationListView()
                .tabItem {
                    Label("轮班", systemImage: "arrow.triangle.2.circlepath")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .tint(FamilyDutyTheme.forest)
        .background(FamilyDutyTheme.pageBackground)
        .accessibilityIdentifier("primary-navigation")
    }
}
