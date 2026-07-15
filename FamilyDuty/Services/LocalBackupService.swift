import Foundation
import SwiftData

@MainActor
struct LocalBackupService {
    static let currentSchemaVersion = 1

    struct BackupPayload: Codable, Equatable {
        let schemaVersion: Int
        let members: [MemberPayload]
        let rules: [RulePayload]
        let tasks: [TaskPayload]
        let records: [RecordPayload]

        struct MemberPayload: Codable, Equatable {
            let id: UUID
            let name: String
            let colorName: String
            let sortOrder: Int
        }

        struct RulePayload: Codable, Equatable {
            let id: UUID
            let title: String
            let weekday: Int
            let startOfRotationWeek: Date
            let isEnabled: Bool
            let score: Int
            let participantIDs: [UUID]
            let participantOrder: [UUID]
        }

        struct TaskPayload: Codable, Equatable {
            let id: UUID
            let title: String
            let scheduledDate: Date
            let sourceScheduledDate: Date?
            let deadline: Date?
            let score: Int
            let isTemporary: Bool
            let isOneOffOverride: Bool?
            let statusRaw: String
            let adjustmentNote: String?
            let assigneeID: UUID?
            let ruleID: UUID?
        }

        struct RecordPayload: Codable, Equatable {
            let id: UUID
            let completedAt: Date
            let workDate: Date
            let score: Int
            let completedByName: String?
            let taskID: UUID
            let completedByID: UUID
        }
    }

    enum BackupError: Error, Equatable, LocalizedError {
        case unsupportedVersion(Int)
        case duplicateIdentifier(String)
        case missingRelationship(String)
        case invalidValue(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version): "不支持的备份版本：\(version)"
            case .duplicateIdentifier(let type): "备份中存在重复的\(type)标识"
            case .missingRelationship(let description): "备份中的\(description)引用不存在"
            case .invalidValue(let description): "备份中的\(description)无效"
            }
        }
    }

    let context: ModelContext
    let calendar: Calendar
    private let saver: (ModelContext) throws -> Void

    init(
        context: ModelContext,
        calendar: Calendar = .current,
        saver: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.calendar = calendar
        self.saver = saver
    }

    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(makePayload())
    }

    func makePayload() throws -> BackupPayload {
        let members = try context.fetch(FetchDescriptor<FamilyMember>())
            .sorted { first, second in
                if first.sortOrder != second.sortOrder { return first.sortOrder < second.sortOrder }
                return first.id.uuidString < second.id.uuidString
            }
        let rules = try context.fetch(FetchDescriptor<ChoreRule>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let tasks = try context.fetch(FetchDescriptor<ChoreTask>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let records = try context.fetch(FetchDescriptor<CompletionRecord>())
            .sorted { $0.id.uuidString < $1.id.uuidString }

        return BackupPayload(
            schemaVersion: Self.currentSchemaVersion,
            members: members.map {
                BackupPayload.MemberPayload(
                    id: $0.id,
                    name: $0.name,
                    colorName: $0.colorName,
                    sortOrder: $0.sortOrder
                )
            },
            rules: rules.map {
                BackupPayload.RulePayload(
                    id: $0.id,
                    title: $0.title,
                    weekday: $0.weekday,
                    startOfRotationWeek: $0.startOfRotationWeek,
                    isEnabled: $0.isEnabled,
                    score: $0.score,
                    participantIDs: $0.participants.map(\.id),
                    participantOrder: $0.participantOrder
                )
            },
            tasks: tasks.map {
                BackupPayload.TaskPayload(
                    id: $0.id,
                    title: $0.title,
                    scheduledDate: $0.scheduledDate,
                    sourceScheduledDate: $0.sourceScheduledDate,
                    deadline: $0.deadline,
                    score: $0.score,
                    isTemporary: $0.isTemporary,
                    isOneOffOverride: $0.isOneOffOverride,
                    statusRaw: $0.statusRaw,
                    adjustmentNote: $0.adjustmentNote,
                    assigneeID: $0.assignee?.id,
                    ruleID: $0.rule?.id
                )
            },
            records: try records.map {
                guard let taskID = $0.task?.id, let completedByID = $0.completedBy?.id else {
                    throw BackupError.missingRelationship("完成记录")
                }
                return BackupPayload.RecordPayload(
                    id: $0.id,
                    completedAt: $0.completedAt,
                    workDate: $0.workDate,
                    score: $0.score,
                    completedByName: $0.completedByName,
                    taskID: taskID,
                    completedByID: completedByID
                )
            }
        )
    }

    func restore(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)
        try restore(payload)
    }

    func restore(_ payload: BackupPayload) throws {
        try validate(payload)

        let existingRecords = try context.fetch(FetchDescriptor<CompletionRecord>())
        let existingTasks = try context.fetch(FetchDescriptor<ChoreTask>())
        let existingRules = try context.fetch(FetchDescriptor<ChoreRule>())
        let existingMembers = try context.fetch(FetchDescriptor<FamilyMember>())
        existingRecords.forEach(context.delete)
        existingTasks.forEach(context.delete)
        existingRules.forEach(context.delete)
        existingMembers.forEach(context.delete)

        let membersByID = Dictionary(uniqueKeysWithValues: payload.members.map {
            let member = FamilyMember(id: $0.id, name: $0.name, colorName: $0.colorName, sortOrder: $0.sortOrder)
            context.insert(member)
            return ($0.id, member)
        })

        let rulesByID = Dictionary(uniqueKeysWithValues: payload.rules.map {
            let participants = $0.participantIDs.compactMap { membersByID[$0] }
            let rule = ChoreRule(
                id: $0.id,
                title: $0.title,
                weekday: $0.weekday,
                startOfRotationWeek: $0.startOfRotationWeek,
                participants: participants,
                isEnabled: $0.isEnabled,
                score: $0.score
            )
            rule.participantOrder = $0.participantOrder
            context.insert(rule)
            return ($0.id, rule)
        })

        let tasksByID = Dictionary(uniqueKeysWithValues: payload.tasks.map {
            let task = ChoreTask(
                id: $0.id,
                title: $0.title,
                scheduledDate: $0.scheduledDate,
                sourceScheduledDate: $0.sourceScheduledDate,
                deadline: $0.deadline,
                score: $0.score,
                assignee: $0.assigneeID.flatMap { membersByID[$0] },
                rule: $0.ruleID.flatMap { rulesByID[$0] },
                isTemporary: $0.isTemporary,
                isOneOffOverride: $0.isOneOffOverride ?? ($0.adjustmentNote != nil),
                status: TaskStatus(rawValue: $0.statusRaw) ?? .pending,
                adjustmentNote: $0.adjustmentNote
            )
            context.insert(task)
            return ($0.id, task)
        })

        for recordPayload in payload.records {
            guard let task = tasksByID[recordPayload.taskID],
                  let member = membersByID[recordPayload.completedByID] else {
                throw BackupError.missingRelationship("完成记录")
            }
            let record = CompletionRecord(
                id: recordPayload.id,
                task: task,
                completedBy: member,
                completedAt: recordPayload.completedAt,
                calendar: calendar
            )
            record.workDate = recordPayload.workDate
            record.score = recordPayload.score
            record.completedByName = recordPayload.completedByName
            context.insert(record)
        }

        do {
            try saver(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func validate(_ payload: BackupPayload) throws {
        guard payload.schemaVersion == Self.currentSchemaVersion else {
            throw BackupError.unsupportedVersion(payload.schemaVersion)
        }
        try validateUnique(payload.members.map(\.id), type: "成员")
        try validateUnique(payload.rules.map(\.id), type: "规则")
        try validateUnique(payload.tasks.map(\.id), type: "任务")
        try validateUnique(payload.records.map(\.id), type: "完成记录")

        let memberIDs = Set(payload.members.map(\.id))
        let ruleIDs = Set(payload.rules.map(\.id))
        let taskIDs = Set(payload.tasks.map(\.id))

        for member in payload.members where member.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw BackupError.invalidValue("成员姓名")
        }

        for rule in payload.rules {
            guard !rule.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BackupError.invalidValue("规则标题")
            }
            guard (1...7).contains(rule.weekday) else {
                throw BackupError.invalidValue("规则星期")
            }
            guard !rule.participantIDs.isEmpty else {
                throw BackupError.invalidValue("规则参与成员")
            }
            guard Set(rule.participantIDs).count == rule.participantIDs.count else {
                throw BackupError.invalidValue("规则参与成员顺序")
            }
            guard Set(rule.participantIDs) == Set(rule.participantOrder),
                  Set(rule.participantIDs).isSubset(of: memberIDs) else {
                throw BackupError.missingRelationship("规则参与成员")
            }
            try ScoreValidationService.validate(score: rule.score)
        }

        for task in payload.tasks {
            guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BackupError.invalidValue("任务标题")
            }
            guard TaskStatus(rawValue: task.statusRaw) != nil else {
                throw BackupError.invalidValue("任务状态")
            }
            try ScoreValidationService.validate(score: task.score)
            try TaskDeadlineService.validate(deadline: task.deadline, scheduledDate: task.scheduledDate, calendar: calendar)
            if let assigneeID = task.assigneeID, !memberIDs.contains(assigneeID) {
                throw BackupError.missingRelationship("任务负责人")
            }
            if let ruleID = task.ruleID, !ruleIDs.contains(ruleID) {
                throw BackupError.missingRelationship("任务来源规则")
            }
            if task.isTemporary, task.ruleID != nil {
                throw BackupError.invalidValue("临时任务来源")
            }
        }

        for record in payload.records {
            guard taskIDs.contains(record.taskID), memberIDs.contains(record.completedByID) else {
                throw BackupError.missingRelationship("完成记录")
            }
            try ScoreValidationService.validate(score: record.score)
        }
    }

    private func validateUnique(_ ids: [UUID], type: String) throws {
        guard Set(ids).count == ids.count else { throw BackupError.duplicateIdentifier(type) }
    }
}
