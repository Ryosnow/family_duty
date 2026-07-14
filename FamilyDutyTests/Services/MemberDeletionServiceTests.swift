import SwiftData
import XCTest
@testable import FamilyDuty

@MainActor
final class MemberDeletionServiceTests: XCTestCase {
    func testMemberReferencedByRuleAndPendingTaskCannotBeDeleted() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let rule = ChoreRule(title: "扫地", weekday: 2, startOfRotationWeek: .now, participants: [member])
        let task = ChoreTask(title: "扫地", scheduledDate: .now, assignee: member, rule: rule)
        context.insert(member)
        context.insert(rule)
        context.insert(task)
        try context.save()

        let blockers = try MemberDeletionService(context: context).blockers(for: member)

        XCTAssertTrue(blockers.contains(.rule("扫地")))
        XCTAssertTrue(blockers.contains(.pendingTask("扫地")))
        XCTAssertThrowsError(try MemberDeletionService(context: context).delete(member))
    }

    func testCompletionRecordKeepsMemberNameSnapshot() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "小红", sortOrder: 0)
        let task = ChoreTask(title: "洗碗", scheduledDate: .now, assignee: member, status: .completed)
        let record = CompletionRecord(task: task, completedBy: member)
        context.insert(member)
        context.insert(task)
        context.insert(record)
        try context.save()

        member.name = "小红（新名字）"

        XCTAssertEqual(record.completedByName, "小红")
        XCTAssertEqual(try MemberDeletionService(context: context).blockers(for: member), [.completionHistory("洗碗")])
    }

    func testUnreferencedMemberCanBeDeleted() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "小明", sortOrder: 0)
        context.insert(member)
        try context.save()

        try MemberDeletionService(context: context).delete(member)

        XCTAssertTrue(try context.fetch(FetchDescriptor<FamilyMember>()).isEmpty)
    }
}
