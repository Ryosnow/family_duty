import Foundation
import SwiftData

enum OnboardingValidationError: Error, Equatable, LocalizedError {
    case missingMemberName

    var errorDescription: String? {
        switch self {
        case .missingMemberName:
            return "请填写所有家庭成员姓名"
        }
    }
}

struct OnboardingMemberDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var colorName: String

    init(id: UUID = UUID(), name: String = "", colorName: String) {
        self.id = id
        self.name = name
        self.colorName = colorName
    }
}

@MainActor
struct OnboardingViewModel {
    let context: ModelContext
    var calendar: Calendar
    let now: Date
    private let saver: (ModelContext) throws -> Void

    init(
        context: ModelContext,
        calendar: Calendar = .current,
        now: Date = .now,
        saver: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.calendar = calendar
        self.now = now
        self.saver = saver
    }

    func finish(memberDrafts: [OnboardingMemberDraft], firstRuleTitle: String) throws {
        guard !memberDrafts.isEmpty,
              memberDrafts.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw OnboardingValidationError.missingMemberName
        }

        let members = memberDrafts.enumerated().map { index, draft in
            let member = FamilyMember(
                name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                colorName: FamilyDutyMemberColor.colorName(for: draft.colorName),
                sortOrder: index
            )
            context.insert(member)
            return member
        }

        do {
            try RotationViewModel(context: context, calendar: calendar, now: now, saver: saver).saveRule(
                title: firstRuleTitle,
                weekday: calendar.component(.weekday, from: now),
                startOfRotationWeek: now,
                participants: members,
                isEnabled: true,
                generateThrough: calendar.date(byAdding: .weekOfYear, value: 4, to: now) ?? now
            )
        } catch {
            members.forEach(context.delete)
            context.rollback()
            throw error
        }
    }
}
