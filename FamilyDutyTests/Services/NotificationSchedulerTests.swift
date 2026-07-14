import UserNotifications
import XCTest
@testable import FamilyDuty

@MainActor
final class NotificationSchedulerTests: XCTestCase {
    func testRefreshSchedulesOnlyTodaysPendingTasksInDailySummary() async throws {
        let calendar = Calendar(identifier: .iso8601)
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let client = NotificationCenterClientSpy()
        let scheduler = NotificationScheduler(client: client, calendar: calendar)
        let tasks = [
            ChoreTask(title: "扫地", scheduledDate: today),
            ChoreTask(title: "洗碗", scheduledDate: today, status: .completed),
            ChoreTask(title: "倒垃圾", scheduledDate: tomorrow)
        ]

        try await scheduler.refreshSchedule(
            for: tasks,
            settings: NotificationSettings(isEnabled: true, dailySummaryHour: 8, overdueHour: 19),
            now: today
        )

        let daily = try XCTUnwrap(client.added.first { $0.identifier == NotificationScheduler.dailySummaryIdentifier })
        XCTAssertTrue(daily.body.contains("扫地"))
        XCTAssertFalse(daily.body.contains("洗碗"))
        XCTAssertFalse(daily.body.contains("倒垃圾"))
        XCTAssertEqual(daily.dateComponents.hour, 8)
    }

    func testRefreshSchedulesOnlyPendingOverdueTasks() async throws {
        let calendar = Calendar(identifier: .iso8601)
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let client = NotificationCenterClientSpy()
        let scheduler = NotificationScheduler(client: client, calendar: calendar)
        let tasks = [
            ChoreTask(title: "擦桌子", scheduledDate: yesterday),
            ChoreTask(title: "浇花", scheduledDate: yesterday, status: .completed)
        ]

        try await scheduler.refreshSchedule(
            for: tasks,
            settings: NotificationSettings(isEnabled: true, dailySummaryHour: 8, overdueHour: 20),
            now: today
        )

        let overdue = try XCTUnwrap(client.added.first { $0.identifier == NotificationScheduler.overdueIdentifier })
        XCTAssertTrue(overdue.body.contains("擦桌子"))
        XCTAssertFalse(overdue.body.contains("浇花"))
        XCTAssertEqual(overdue.dateComponents.hour, 20)
    }

    func testRefreshRemovesOnlyPreviouslyManagedRequests() async throws {
        let client = NotificationCenterClientSpy()
        client.pendingIdentifiers = [
            NotificationScheduler.dailySummaryIdentifier,
            NotificationScheduler.overdueIdentifier,
            "another-app-style-request"
        ]
        let scheduler = NotificationScheduler(client: client)

        try await scheduler.refreshSchedule(
            for: [],
            settings: NotificationSettings(isEnabled: false, dailySummaryHour: 8, overdueHour: 19),
            now: .now
        )

        XCTAssertEqual(
            Set(client.removedIdentifiers),
            Set([NotificationScheduler.dailySummaryIdentifier, NotificationScheduler.overdueIdentifier])
        )
    }
}

private final class NotificationCenterClientSpy: NotificationCenterClient {
    struct AddedRequest {
        let identifier: String
        let title: String
        let body: String
        let dateComponents: DateComponents
    }

    var pendingIdentifiers: [String] = []
    var removedIdentifiers: [String] = []
    var added: [AddedRequest] = []

    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func pendingRequestIdentifiers() async -> [String] { pendingIdentifiers }
    func removePendingRequests(withIdentifiers identifiers: [String]) { removedIdentifiers.append(contentsOf: identifiers) }
    func add(identifier: String, title: String, body: String, dateComponents: DateComponents) async throws {
        added.append(AddedRequest(identifier: identifier, title: title, body: body, dateComponents: dateComponents))
    }
}
