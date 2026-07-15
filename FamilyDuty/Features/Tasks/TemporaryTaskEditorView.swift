import SwiftData
import SwiftUI

struct TemporaryTaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FamilyMember.sortOrder) private var members: [FamilyMember]
    @State private var title = ""
    @State private var selectedPresetID: String?
    @State private var scheduledDate = Date.now
    @State private var hasDeadline = false
    @State private var deadline = Date.now
    @State private var scoreText = "1"
    @State private var assigneeID: UUID?
    @State private var errorMessage: String?

    init(initialDraft: TemporaryTaskDraft? = nil) {
        _title = State(initialValue: initialDraft?.title ?? "")
        _scoreText = State(initialValue: initialDraft.map { String($0.score) } ?? "1")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("快速选择任务 🧰", selection: $selectedPresetID) {
                    Text("选择预设").tag(Optional<String>.none)
                    ForEach(TaskPresetCatalog.all) { preset in
                        Text("\(preset.emoji) \(preset.title)")
                            .tag(Optional(preset.id))
                            .accessibilityLabel(preset.title)
                            .accessibilityIdentifier("temporary-task-preset-\(preset.id)")
                    }
                }
                .accessibilityIdentifier("temporary-task-preset-picker")
                .accessibilityLabel("快速选择任务")
                .onChange(of: selectedPresetID) { _, presetID in
                    applyPreset(withID: presetID)
                }

                TextField("任务名称", text: $title)
                    .onChange(of: title) { _, newTitle in
                        guard let selectedPresetID,
                              let preset = TaskPresetCatalog.all.first(where: { $0.id == selectedPresetID }) else {
                            return
                        }
                        if newTitle != preset.title {
                            self.selectedPresetID = nil
                        }
                    }
                DatePicker("日期", selection: $scheduledDate, displayedComponents: .date)
                TextField("得分", text: $scoreText)
                    .keyboardType(.numberPad)
                Toggle("设置 Deadline", isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker("最晚日期", selection: $deadline, displayedComponents: .date)
                }
                Picker("负责人", selection: $assigneeID) {
                    Text("待领取").tag(Optional<UUID>.none)
                    ForEach(members) { member in
                        Text(member.name).tag(Optional(member.id))
                    }
                }
            }
            .navigationTitle("新增临时任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() } }
            }
            .alert("无法保存", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .onChange(of: hasDeadline) { _, enabled in
                if enabled {
                    deadline = scheduledDate
                }
            }
        }
    }

    private func save() {
        do {
            try TemporaryTaskViewModel(context: context).createTask(
                title: title,
                scheduledDate: scheduledDate,
                deadline: hasDeadline ? deadline : nil,
                score: Int(scoreText) ?? 0,
                assignee: members.first { $0.id == assigneeID }
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyPreset(withID id: String?) {
        guard let id,
              let preset = TaskPresetCatalog.all.first(where: { $0.id == id }) else {
            return
        }
        title = preset.title
    }
}
