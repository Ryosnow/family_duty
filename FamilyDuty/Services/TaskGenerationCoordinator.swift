import Foundation
import SwiftData

@MainActor
struct TaskGenerationCoordinator {
    let context: ModelContext
    let calendar: Calendar
    let horizonWeeks: Int
    private let saver: (ModelContext) throws -> Void

    init(
        context: ModelContext,
        calendar: Calendar = .current,
        horizonWeeks: Int = 8,
        saver: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.calendar = calendar
        self.horizonWeeks = max(horizonWeeks, 1)
        self.saver = saver
    }

    func refresh(now: Date = .now) throws {
        try refresh(for: context.fetch(FetchDescriptor<ChoreRule>()), now: now)
    }

    func refresh(for rules: [ChoreRule], now: Date = .now) throws {
        let endDate = calendar.date(byAdding: .weekOfYear, value: horizonWeeks, to: now) ?? now
        try TaskGenerationService(
            context: context,
            calendar: calendar,
            now: now,
            saver: saver
        ).ensureTasks(for: rules, through: endDate)
    }
}
