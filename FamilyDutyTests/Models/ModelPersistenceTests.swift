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
}
