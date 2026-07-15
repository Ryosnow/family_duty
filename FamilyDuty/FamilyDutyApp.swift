import SwiftUI
import SwiftData

@main
struct FamilyDutyApp: App {
    private let modelContainer: ModelContainer

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        do {
            modelContainer = try ModelContainerFactory.makeContainer(inMemory: isUITesting)
        } catch {
            fatalError("无法加载家庭数据模型容器：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .refreshNotificationScheduleWhenTasksChange()
                .modelContainer(modelContainer)
        }
    }
}
