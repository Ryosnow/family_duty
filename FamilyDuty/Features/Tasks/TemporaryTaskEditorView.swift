import SwiftData
import SwiftUI

struct TemporaryTaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FamilyMember.sortOrder) private var members: [FamilyMember]
    @State private var title = ""
    @State private var scheduledDate = Date.now
    @State private var assigneeID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("任务名称", text: $title)
                DatePicker("日期", selection: $scheduledDate, displayedComponents: .date)
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
        }
    }

    private func save() {
        do {
            try TemporaryTaskViewModel(context: context).createTask(
                title: title,
                scheduledDate: scheduledDate,
                assignee: members.first { $0.id == assigneeID }
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
