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
        XCTAssertTrue(try context.fetch(FetchDescriptor<ChoreRule>()).isEmpty)
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
