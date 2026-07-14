import SwiftData
import XCTest
@testable import FamilyDuty

@MainActor
final class CompletionServiceTests: XCTestCase {
    private enum SaveError: Error { case failed }

    func testCompleteCreatesRecordAndMarksTaskCompleted() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "扫地", scheduledDate: .now, assignee: member)
        context.insert(member)
        context.insert(task)

        try CompletionService(context: context).complete(task, by: member)

        XCTAssertEqual(task.status, .completed)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CompletionRecord>()).count, 1)
    }

    func testSaveFailureRollsBackTaskAndCompletionRecord() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "扫地", scheduledDate: .now, assignee: member)
        context.insert(member)
        context.insert(task)
        let service = CompletionService(context: context) { _ in throw SaveError.failed }

        XCTAssertThrowsError(try service.complete(task, by: member))

        XCTAssertEqual(task.status, .pending)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CompletionRecord>()).isEmpty)
    }
}
