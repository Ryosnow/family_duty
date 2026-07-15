import SwiftData
import XCTest
@testable import FamilyDuty

@MainActor
final class RotationViewModelTests: XCTestCase {
    func testSaveRulePersistsRuleAndGeneratesFutureTask() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "小明", sortOrder: 0)
        context.insert(member)
        let calendar = Calendar(identifier: .iso8601)
        let endDate = calendar.date(byAdding: .day, value: 28, to: .now)!
        let viewModel = RotationViewModel(context: context, calendar: calendar)

        let rule = try viewModel.saveRule(
            title: "扫地",
            weekday: calendar.component(.weekday, from: .now),
            startOfRotationWeek: .now,
            participants: [member],
            isEnabled: true,
            generateThrough: endDate
        )

        XCTAssertEqual(rule.title, "扫地")
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChoreRule>()).count, 1)
        XCTAssertFalse(try context.fetch(FetchDescriptor<ChoreTask>()).isEmpty)
    }

    func testSaveRuleRejectsBlankTitle() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let viewModel = RotationViewModel(context: container.mainContext)

        XCTAssertThrowsError(
            try viewModel.saveRule(
                title: "   ",
                weekday: 2,
                startOfRotationWeek: .now,
                participants: [member],
                isEnabled: true,
                generateThrough: .now
            )
        ) { error in
            XCTAssertEqual(error as? RotationRuleValidationError, .missingTitle)
        }
    }

    func testSaveRuleRejectsEmptyParticipants() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let viewModel = RotationViewModel(context: container.mainContext)

        XCTAssertThrowsError(
            try viewModel.saveRule(
                title: "扫地",
                weekday: 2,
                startOfRotationWeek: .now,
                participants: [],
                isEnabled: true,
                generateThrough: .now
            )
        ) { error in
            XCTAssertEqual(error as? RotationRuleValidationError, .missingParticipants)
        }
    }

    func testMovingParticipantChangesRotationOrder() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let viewModel = RotationViewModel(context: container.mainContext)
        let first = FamilyMember(name: "小明", sortOrder: 0)
        let second = FamilyMember(name: "小红", sortOrder: 1)

        let reordered = viewModel.moving([first, second], fromOffsets: IndexSet(integer: 1), toOffset: 0)

        XCTAssertEqual(reordered.map(\.name), ["小红", "小明"])
    }

    func testEditingRuleRegeneratesOnlyUnadjustedPendingTasks() throws {
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
        let generated = ChoreTask(title: "扫地", scheduledDate: today, assignee: first, rule: rule)
        let adjusted = ChoreTask(
            title: "扫地",
            scheduledDate: calendar.date(byAdding: .day, value: 1, to: today)!,
            assignee: first,
            rule: rule,
            adjustmentNote: "本周改派"
        )
        [first, second].forEach(context.insert)
        context.insert(rule)
        context.insert(generated)
        context.insert(adjusted)
        try context.save()

        try RotationViewModel(context: context, calendar: calendar).saveRule(
            existingRule: rule,
            title: "扫地",
            weekday: rule.weekday,
            startOfRotationWeek: today,
            participants: [second, first],
            isEnabled: true,
            generateThrough: today
        )

        let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
        XCTAssertEqual(tasks.count, 2)
        XCTAssertEqual(tasks.first { $0.adjustmentNote == nil }?.assignee?.id, second.id)
        XCTAssertEqual(tasks.first { $0.adjustmentNote != nil }?.id, adjusted.id)
    }

    func testAdjustingOneTaskDoesNotChangeFollowingRotation() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .iso8601)
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
        let first = FamilyMember(name: "小明", sortOrder: 0)
        let second = FamilyMember(name: "小红", sortOrder: 1)
        let rule = ChoreRule(title: "扫地", weekday: 2, startOfRotationWeek: start, participants: [first, second])
        let task = ChoreTask(title: "扫地", scheduledDate: start, assignee: first, rule: rule)
        [first, second].forEach(context.insert)
        context.insert(rule)
        context.insert(task)

        try RotationViewModel(context: context, calendar: calendar).adjust(
            task,
            assignee: second,
            scheduledDate: start,
            cancellationReason: nil
        )

        XCTAssertEqual(task.assignee?.id, second.id)
        XCTAssertNotNil(task.adjustmentNote)
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
        XCTAssertEqual(RotationScheduler().assignee(for: rule, weekOf: nextWeek, calendar: calendar)?.id, second.id)
        XCTAssertEqual(rule.orderedParticipants.map(\.id), [first.id, second.id])
    }

    func testReschedulingOneTaskChangesOnlyItsInstanceDate() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let originalDate = Date.now
        let newDate = Calendar.current.date(byAdding: .day, value: 2, to: originalDate)!
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let rule = ChoreRule(title: "扫地", weekday: 2, startOfRotationWeek: originalDate, participants: [member])
        let task = ChoreTask(title: "扫地", scheduledDate: originalDate, assignee: member, rule: rule)
        context.insert(member)
        context.insert(rule)
        context.insert(task)

        try RotationViewModel(context: context).adjust(
            task,
            assignee: member,
            scheduledDate: newDate,
            cancellationReason: nil
        )

        XCTAssertEqual(task.scheduledDate, newDate)
        XCTAssertEqual(rule.weekday, 2)
    }

    func testCancellingOneTaskRecordsReasonWithoutDisablingRule() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let rule = ChoreRule(title: "扫地", weekday: 2, startOfRotationWeek: .now, participants: [member])
        let task = ChoreTask(title: "扫地", scheduledDate: .now, assignee: member, rule: rule)
        context.insert(member)
        context.insert(rule)
        context.insert(task)

        try RotationViewModel(context: context).adjust(
            task,
            assignee: member,
            scheduledDate: task.scheduledDate,
            cancellationReason: "全家外出"
        )

        XCTAssertEqual(task.status, .cancelled)
        XCTAssertEqual(task.adjustmentNote, "全家外出")
        XCTAssertTrue(rule.isEnabled)
    }

    func testAdjustingOneTaskCanSetAndClearDeadline() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let scheduledDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        let deadline = calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))!
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "扫地", scheduledDate: scheduledDate, assignee: member)
        context.insert(member)
        context.insert(task)

        let viewModel = RotationViewModel(context: context, calendar: calendar)
        try viewModel.adjust(task, assignee: member, scheduledDate: scheduledDate, deadline: deadline, cancellationReason: nil)

        XCTAssertEqual(task.deadline, calendar.startOfDay(for: deadline))

        try viewModel.adjust(task, assignee: member, scheduledDate: scheduledDate, deadline: nil, cancellationReason: nil)

        XCTAssertNil(task.deadline)
        XCTAssertEqual(TaskDeadlineService.effectiveDeadline(for: task, calendar: calendar), scheduledDate)
    }

    func testReschedulingOneTaskCanUpdateDeadline() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let originalDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        let newDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 17))!
        let deadline = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20))!
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "扫地", scheduledDate: originalDate, assignee: member)
        context.insert(member)
        context.insert(task)

        try RotationViewModel(context: context, calendar: calendar).adjust(
            task,
            assignee: member,
            scheduledDate: newDate,
            deadline: deadline,
            cancellationReason: nil
        )

        XCTAssertEqual(task.scheduledDate, newDate)
        XCTAssertEqual(task.deadline, calendar.startOfDay(for: deadline))
    }

    func testAdjustRejectsInvalidDeadlineWithoutPartiallyUpdatingTask() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let scheduledDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        let invalidDeadline = calendar.date(from: DateComponents(year: 2026, month: 7, day: 14))!
        let first = FamilyMember(name: "小明", sortOrder: 0)
        let second = FamilyMember(name: "小红", sortOrder: 1)
        let task = ChoreTask(title: "扫地", scheduledDate: scheduledDate, assignee: first)
        context.insert(first)
        context.insert(second)
        context.insert(task)

        XCTAssertThrowsError(
            try RotationViewModel(context: context, calendar: calendar).adjust(
                task,
                assignee: second,
                scheduledDate: calendar.date(byAdding: .day, value: 1, to: scheduledDate)!,
                deadline: invalidDeadline,
                cancellationReason: nil
            )
        ) { error in
            XCTAssertEqual(error as? TaskDeadlineValidationError, .beforeScheduledDate)
        }

        XCTAssertEqual(task.assignee?.id, first.id)
        XCTAssertEqual(task.scheduledDate, scheduledDate)
        XCTAssertNil(task.deadline)
    }
}
