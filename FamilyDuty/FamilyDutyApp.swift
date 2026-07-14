import SwiftUI
import SwiftData

@main
struct FamilyDutyApp: App {
    private let modelContainer: ModelContainer

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        modelContainer = try! ModelContainerFactory.makeContainer(inMemory: isUITesting)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .refreshNotificationScheduleWhenTasksChange()
                .modelContainer(modelContainer)
        }
    }
}
