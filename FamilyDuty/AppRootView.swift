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
        guard arguments.contains("-seedMember") || arguments.contains("-seedDashboardTask") else { return }
        let member = FamilyMember(name: "小明", sortOrder: 0)
        context.insert(member)
        if arguments.contains("-seedDashboardTask") {
            context.insert(ChoreTask(title: "扫地", scheduledDate: .now, assignee: member))
        }
        try? context.save()
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
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
        .accessibilityIdentifier("primary-navigation")
    }
}
