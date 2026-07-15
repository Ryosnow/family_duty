import SwiftData
import XCTest
@testable import FamilyDuty

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testFinishCreatesAllMembersAndIncludesThemInFirstRule() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = testCalendar
        let now = date(year: 2026, month: 7, day: 15, calendar: calendar)
        let drafts = [
            OnboardingMemberDraft(name: "小明", colorName: "blue"),
            OnboardingMemberDraft(name: "小红", colorName: "purple")
        ]

        try OnboardingViewModel(context: context, calendar: calendar, now: now)
            .finish(memberDrafts: drafts, firstRuleTitle: "扫地")

        let members = try context.fetch(FetchDescriptor<FamilyMember>()).sorted { $0.sortOrder < $1.sortOrder }
        let rule = try XCTUnwrap(try context.fetch(FetchDescriptor<ChoreRule>()).first)

        XCTAssertEqual(members.map(\.name), ["小明", "小红"])
        XCTAssertEqual(members.map(\.colorName), ["blue", "purple"])
        XCTAssertEqual(rule.participantOrder, members.map(\.id))
        XCTAssertEqual(rule.orderedParticipants.map(\.id), members.map(\.id))
    }

    func testFinishRejectsBlankMemberNameBeforeCreatingData() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let drafts = [OnboardingMemberDraft(name: "  ", colorName: "blue")]

        XCTAssertThrowsError(
            try OnboardingViewModel(context: context).finish(memberDrafts: drafts, firstRuleTitle: "扫地")
        ) { error in
            XCTAssertEqual(error as? OnboardingValidationError, .missingMemberName)
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<FamilyMember>()).isEmpty)
    }

    func testFinishSaveFailureRollsBackMembersAndRule() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let drafts = [OnboardingMemberDraft(name: "小明", colorName: "blue")]

        XCTAssertThrowsError(
            try OnboardingViewModel(
                context: context,
                saver: { _ in throw TestSaveError.failed }
            ).finish(memberDrafts: drafts, firstRuleTitle: "扫地")
        )

        XCTAssertTrue(try context.fetch(FetchDescriptor<FamilyMember>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ChoreRule>()).isEmpty)
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private enum TestSaveError: Error {
        case failed
    }
}
