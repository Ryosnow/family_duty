import SwiftData
import XCTest
@testable import FamilyDuty

@MainActor
final class LocalBackupServiceTests: XCTestCase {
    private enum SaveError: Error { case failed }

    func testExportAndRestoreRoundTripPreservesRelationshipsAndSnapshots() throws {
        let sourceContainer = try ModelContainerFactory.makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext
        let first = FamilyMember(name: "小明", sortOrder: 0)
        let second = FamilyMember(name: "小红", sortOrder: 1)
        let rule = ChoreRule(
            title: "扫地",
            weekday: 2,
            startOfRotationWeek: .now,
            participants: [second, first],
            score: 3
        )
        let recurringTask = ChoreTask(
            title: "扫地",
            scheduledDate: .now,
            sourceScheduledDate: .now,
            deadline: Calendar.current.date(byAdding: .day, value: 1, to: .now),
            score: 3,
            assignee: second,
            rule: rule,
            isOneOffOverride: true,
            status: .completed
        )
        let temporaryTask = ChoreTask(
            title: "收快递",
            scheduledDate: .now,
            score: 2,
            assignee: first,
            isTemporary: true
        )
        let record = CompletionRecord(task: recurringTask, completedBy: second)
        sourceContext.insert(first)
        sourceContext.insert(second)
        sourceContext.insert(rule)
        sourceContext.insert(recurringTask)
        sourceContext.insert(temporaryTask)
        sourceContext.insert(record)
        try sourceContext.save()

        let data = try LocalBackupService(context: sourceContext).exportData()

        let destinationContainer = try ModelContainerFactory.makeInMemoryContainer()
        let destinationContext = destinationContainer.mainContext
        try LocalBackupService(context: destinationContext).restore(from: data)

        let members = try destinationContext.fetch(FetchDescriptor<FamilyMember>()).sorted { $0.sortOrder < $1.sortOrder }
        let rules = try destinationContext.fetch(FetchDescriptor<ChoreRule>())
        let tasks = try destinationContext.fetch(FetchDescriptor<ChoreTask>())
        let records = try destinationContext.fetch(FetchDescriptor<CompletionRecord>())

        XCTAssertEqual(members.map(\.name), ["小明", "小红"])
        XCTAssertEqual(rules.first?.participantOrder, [second.id, first.id])
        XCTAssertEqual(tasks.count, 2)
        XCTAssertEqual(tasks.first(where: { !$0.isTemporary })?.rule?.title, "扫地")
        XCTAssertNotNil(tasks.first(where: { !$0.isTemporary })?.sourceScheduledDate)
        XCTAssertEqual(tasks.first(where: { !$0.isTemporary })?.isOneOffOverride, true)
        XCTAssertEqual(tasks.first(where: { $0.isTemporary })?.assignee?.name, "小明")
        XCTAssertEqual(records.first?.completedByName, "小红")
        XCTAssertEqual(records.first?.task?.title, "扫地")
    }

    func testInvalidBackupDoesNotMutateExistingData() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "原有成员", sortOrder: 0)
        context.insert(member)
        try context.save()

        let invalidData = Data("{\"schemaVersion\":1,\"members\":[],\"rules\":[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"title\":\"无效规则\",\"weekday\":2,\"startOfRotationWeek\":\"2026-07-15T00:00:00Z\",\"isEnabled\":true,\"score\":1,\"participantIDs\":[\"00000000-0000-0000-0000-000000000099\"],\"participantOrder\":[\"00000000-0000-0000-0000-000000000099\"]}],\"tasks\":[],\"records\":[]}".utf8)

        XCTAssertThrowsError(try LocalBackupService(context: context).restore(from: invalidData))
        XCTAssertEqual(try context.fetch(FetchDescriptor<FamilyMember>()).map(\.name), ["原有成员"])
    }

    func testRestoreSaveFailureRollsBackAllImportedObjects() throws {
        let sourceContainer = try ModelContainerFactory.makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext
        let sourceMember = FamilyMember(name: "备份成员", sortOrder: 0)
        sourceContext.insert(sourceMember)
        try sourceContext.save()
        let data = try LocalBackupService(context: sourceContext).exportData()

        let destinationContainer = try ModelContainerFactory.makeInMemoryContainer()
        let destinationContext = destinationContainer.mainContext
        XCTAssertThrowsError(
            try LocalBackupService(context: destinationContext) { _ in throw SaveError.failed }
                .restore(from: data)
        )

        XCTAssertTrue(try destinationContext.fetch(FetchDescriptor<FamilyMember>()).isEmpty)
    }

    func testRestoreRejectsInvalidWeekday() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let data = Data("""
        {
          "schemaVersion": 1,
          "members": [{
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "小明",
            "colorName": "blue",
            "sortOrder": 0
          }],
          "rules": [{
            "id": "00000000-0000-0000-0000-000000000002",
            "title": "扫地",
            "weekday": 8,
            "startOfRotationWeek": "2026-07-15T00:00:00Z",
            "isEnabled": true,
            "score": 1,
            "participantIDs": ["00000000-0000-0000-0000-000000000001"],
            "participantOrder": ["00000000-0000-0000-0000-000000000001"]
          }],
          "tasks": [],
          "records": []
        }
        """.utf8)

        XCTAssertThrowsError(try LocalBackupService(context: context).restore(from: data)) { error in
            XCTAssertEqual(error as? LocalBackupService.BackupError, .invalidValue("规则星期"))
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<FamilyMember>()).isEmpty)
    }
}
