import SwiftData
import XCTest
@testable import FamilyDuty

final class ModelPersistenceTests: XCTestCase {
    func testTaskCanBeSavedWithAnOptionalRule() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "扫地", scheduledDate: .now, assignee: member, rule: nil, isTemporary: true)

        context.insert(member)
        context.insert(task)
        try context.save()

        let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertNil(tasks[0].rule)
        XCTAssertEqual(tasks[0].assignee?.name, "小明")
    }

    func testTaskCanPersistAnOptionalDeadline() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let scheduledDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        let deadline = calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))!
        let task = ChoreTask(title: "浇花", scheduledDate: scheduledDate, deadline: deadline)

        context.insert(task)
        try context.save()

        let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
        XCTAssertEqual(tasks.first?.deadline, deadline)
    }

    func testTaskAndCompletionRecordPersistScoreSnapshots() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "浇花", scheduledDate: .now, score: 2, assignee: member, status: .completed)
        let record = CompletionRecord(task: task, completedBy: member)

        context.insert(member)
        context.insert(task)
        context.insert(record)
        try context.save()

        let savedTask = try XCTUnwrap(try context.fetch(FetchDescriptor<ChoreTask>()).first)
        let savedRecord = try XCTUnwrap(try context.fetch(FetchDescriptor<CompletionRecord>()).first)
        XCTAssertEqual(savedTask.score, 2)
        XCTAssertEqual(savedRecord.score, 2)
        XCTAssertEqual(savedRecord.workDate, Calendar.current.startOfDay(for: task.scheduledDate))
    }
}
