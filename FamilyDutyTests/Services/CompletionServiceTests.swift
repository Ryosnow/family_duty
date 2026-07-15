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

    func testCompleteSnapshotsTaskScoreAndScheduledWorkDate() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let scheduledDate = calendar.date(byAdding: .day, value: -1, to: .now)!
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "整理书桌", scheduledDate: scheduledDate, score: 3, assignee: member)
        context.insert(member)
        context.insert(task)

        try CompletionService(context: context, calendar: calendar)
            .complete(task, by: member, at: .now)

        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<CompletionRecord>()).first)
        XCTAssertEqual(record.score, 3)
        XCTAssertEqual(record.workDate, calendar.startOfDay(for: scheduledDate))
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

    func testCompleteRejectsCancelledTaskWithoutCreatingRecord() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "取消的任务", scheduledDate: .now, assignee: member, status: .cancelled)
        context.insert(member)
        context.insert(task)
        try context.save()

        XCTAssertThrowsError(try CompletionService(context: context).complete(task, by: member)) { error in
            XCTAssertEqual(error as? CompletionError, .taskNotPending)
        }
        XCTAssertEqual(task.status, .cancelled)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CompletionRecord>()).isEmpty)
    }

    func testUndoCompletionReopensTaskAndDeletesOnlyLatestRecord() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "扫地", scheduledDate: .now, assignee: member, status: .completed)
        let older = CompletionRecord(task: task, completedBy: member, completedAt: calendar.date(byAdding: .minute, value: -2, to: .now) ?? .now)
        let latest = CompletionRecord(task: task, completedBy: member, completedAt: .now)
        context.insert(member)
        context.insert(task)
        context.insert(older)
        context.insert(latest)
        try context.save()

        try CompletionService(context: context).undoCompletion(task)

        XCTAssertEqual(task.status, .pending)
        let records = try context.fetch(FetchDescriptor<CompletionRecord>())
        XCTAssertEqual(records.map(\.id), [older.id])
    }

    func testUndoCompletionRejectsCompletedTaskWithoutACompletionRecord() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let task = ChoreTask(title: "扫地", scheduledDate: .now, status: .completed)
        context.insert(task)
        try context.save()

        XCTAssertThrowsError(try CompletionService(context: context).undoCompletion(task)) { error in
            XCTAssertEqual(error as? CompletionError, .missingCompletionRecord)
        }
        XCTAssertEqual(task.status, .completed)
    }

    func testUndoSaveFailureRestoresTaskAndCompletionRecord() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "扫地", scheduledDate: .now, assignee: member, status: .completed)
        let record = CompletionRecord(task: task, completedBy: member)
        context.insert(member)
        context.insert(task)
        context.insert(record)
        try context.save()

        XCTAssertThrowsError(
            try CompletionService(context: context) { _ in throw SaveError.failed }
                .undoCompletion(task)
        )

        XCTAssertEqual(task.status, .completed)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CompletionRecord>()).map(\.id), [record.id])
    }
}
