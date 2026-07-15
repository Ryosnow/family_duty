import SwiftData
import XCTest
@testable import FamilyDuty

@MainActor
final class TemporaryTaskViewModelTests: XCTestCase {
    func testCreateAssignedTemporaryTaskDoesNotCreateRule() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "小明", sortOrder: 0)
        context.insert(member)

        let task = try TemporaryTaskViewModel(context: context).createTask(
            title: "擦窗户",
            scheduledDate: .now,
            assignee: member
        )

        XCTAssertTrue(task.isTemporary)
        XCTAssertEqual(task.assignee?.id, member.id)
        XCTAssertNil(task.rule)
        XCTAssertEqual(task.score, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ChoreRule>()).isEmpty)
    }

    func testCreateTaskPersistsConfiguredScore() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()

        let task = try TemporaryTaskViewModel(context: container.mainContext).createTask(
            title: "擦窗户",
            scheduledDate: .now,
            score: 2,
            assignee: nil
        )

        XCTAssertEqual(task.score, 2)
    }

    func testCreateTaskRejectsNonPositiveScore() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()

        XCTAssertThrowsError(
            try TemporaryTaskViewModel(context: container.mainContext).createTask(
                title: "擦窗户",
                scheduledDate: .now,
                score: 0,
                assignee: nil
            )
        ) { error in
            XCTAssertEqual(error as? ScoreValidationError, .invalidScore)
        }
    }

    func testCreateUnassignedTaskCanBeClaimed() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "小红", sortOrder: 0)
        context.insert(member)
        let viewModel = TemporaryTaskViewModel(context: context)
        let task = try viewModel.createTask(title: "整理阳台", scheduledDate: .now, assignee: nil)

        XCTAssertNil(task.assignee)
        try viewModel.claim(task, by: member)

        XCTAssertEqual(task.assignee?.id, member.id)
        XCTAssertEqual(task.status, .pending)
    }

    func testCreateTaskRejectsBlankTitle() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let viewModel = TemporaryTaskViewModel(context: container.mainContext)

        XCTAssertThrowsError(try viewModel.createTask(title: "  ", scheduledDate: .now, assignee: nil)) { error in
            XCTAssertEqual(error as? TemporaryTaskValidationError, .missingTitle)
        }
    }

    func testCreateTaskPersistsExplicitDeadline() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let scheduledDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        let deadline = calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))!

        let task = try TemporaryTaskViewModel(context: context, calendar: calendar).createTask(
            title: "整理阳台",
            scheduledDate: scheduledDate,
            deadline: deadline,
            assignee: nil
        )

        XCTAssertEqual(task.deadline, calendar.startOfDay(for: deadline))
    }

    func testCreateTaskWithoutDeadlineUsesScheduledDayByDefault() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let scheduledDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!

        let task = try TemporaryTaskViewModel(context: context).createTask(
            title: "整理阳台",
            scheduledDate: scheduledDate,
            deadline: nil,
            assignee: nil
        )

        XCTAssertNil(task.deadline)
        XCTAssertEqual(TaskDeadlineService.effectiveDeadline(for: task, calendar: calendar), scheduledDate)
    }

    func testCreateTaskRejectsDeadlineBeforeScheduledDate() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let scheduledDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        let deadline = calendar.date(from: DateComponents(year: 2026, month: 7, day: 14))!

        XCTAssertThrowsError(
            try TemporaryTaskViewModel(context: container.mainContext).createTask(
                title: "整理阳台",
                scheduledDate: scheduledDate,
                deadline: deadline,
                assignee: nil
            )
        ) { error in
            XCTAssertEqual(error as? TaskDeadlineValidationError, .beforeScheduledDate)
        }
    }

    func testClaimRejectsTaskThatAlreadyHasAssignee() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let first = FamilyMember(name: "小明", sortOrder: 0)
        let second = FamilyMember(name: "小红", sortOrder: 1)
        [first, second].forEach(context.insert)
        let viewModel = TemporaryTaskViewModel(context: context)
        let task = try viewModel.createTask(title: "擦桌子", scheduledDate: .now, assignee: first)

        XCTAssertThrowsError(try viewModel.claim(task, by: second)) { error in
            XCTAssertEqual(error as? TemporaryTaskValidationError, .alreadyAssigned)
        }
        XCTAssertEqual(task.assignee?.id, first.id)
    }
}
