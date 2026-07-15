import SwiftData
import XCTest
@testable import FamilyDuty

@MainActor
final class TaskGenerationServiceTests: XCTestCase {
    func testEnsureTasksGeneratesWeeklyTasksWithoutDuplicates() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: .now)
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let rule = ChoreRule(
            title: "扫地",
            weekday: calendar.component(.weekday, from: today),
            startOfRotationWeek: today,
            participants: [member]
        )
        context.insert(member)
        context.insert(rule)
        let service = TaskGenerationService(context: context, calendar: calendar)
        let endDate = calendar.date(byAdding: .weekOfYear, value: 2, to: today)!

        try service.ensureTasks(for: [rule], through: endDate)
        try service.ensureTasks(for: [rule], through: endDate)

        let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
        XCTAssertEqual(tasks.count, 3)
        XCTAssertTrue(tasks.allSatisfy { $0.rule?.id == rule.id && !$0.isTemporary })
    }

    func testEnsureTasksCopiesRuleScoreIntoGeneratedTaskSnapshot() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let rule = ChoreRule(
            title: "擦窗户",
            weekday: calendar.component(.weekday, from: today),
            startOfRotationWeek: today,
            participants: [member],
            score: 3
        )
        context.insert(member)
        context.insert(rule)

        try TaskGenerationService(context: context, calendar: calendar)
            .ensureTasks(for: [rule], through: today)

        let task = try XCTUnwrap(try context.fetch(FetchDescriptor<ChoreTask>()).first)
        XCTAssertEqual(task.score, 3)
    }

    func testEnsureTasksPreservesExistingAdjustedTask() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .iso8601)
        let today = calendar.startOfDay(for: .now)
        let first = FamilyMember(name: "小明", sortOrder: 0)
        let second = FamilyMember(name: "小红", sortOrder: 1)
        let rule = ChoreRule(
            title: "扫地",
            weekday: calendar.component(.weekday, from: today),
            startOfRotationWeek: today,
            participants: [first, second]
        )
        let adjusted = ChoreTask(
            title: "扫地",
            scheduledDate: today,
            assignee: second,
            rule: rule,
            adjustmentNote: "本周改派"
        )
        [first, second].forEach(context.insert)
        context.insert(rule)
        context.insert(adjusted)
        try context.save()

        try TaskGenerationService(context: context, calendar: calendar)
            .ensureTasks(for: [rule], through: today)

        let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].id, adjusted.id)
        XCTAssertEqual(tasks[0].assignee?.id, second.id)
    }

    func testEnsureTasksUsesOriginalOccurrenceDateForRescheduledTask() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .iso8601)
        let today = calendar.startOfDay(for: .now)
        let movedDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: today))
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let rule = ChoreRule(
            title: "扫地",
            weekday: calendar.component(.weekday, from: today),
            startOfRotationWeek: today,
            participants: [member]
        )
        let adjusted = ChoreTask(
            title: "扫地",
            scheduledDate: movedDate,
            sourceScheduledDate: today,
            assignee: member,
            rule: rule,
            isOneOffOverride: true,
            adjustmentNote: "改期"
        )
        context.insert(member)
        context.insert(rule)
        context.insert(adjusted)
        try context.save()

        try TaskGenerationService(context: context, calendar: calendar, now: today)
            .ensureTasks(for: [rule], through: today)

        let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
        XCTAssertEqual(tasks.map(\.id), [adjusted.id])
        XCTAssertEqual(tasks.first?.scheduledDate, movedDate)
    }
}
