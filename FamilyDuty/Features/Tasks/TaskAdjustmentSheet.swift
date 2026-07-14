import SwiftData
import SwiftUI

struct TaskAdjustmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FamilyMember.sortOrder) private var members: [FamilyMember]

    let task: ChoreTask
    @State private var memberID: UUID?
    @State private var scheduledDate = Date.now
    @State private var isCancelled = false
    @State private var cancellationReason = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("本次任务") {
                    Picker("负责人", selection: $memberID) {
                        ForEach(members) { member in
                            Text(member.name).tag(Optional(member.id))
                        }
                    }
                    .disabled(isCancelled)
                    DatePicker("日期", selection: $scheduledDate, displayedComponents: .date)
                        .disabled(isCancelled)
                }

                Section("取消") {
                    Toggle("仅取消这一次", isOn: $isCancelled)
                    if isCancelled {
                        TextField("取消原因", text: $cancellationReason, axis: .vertical)
                    }
                }
            }
            .navigationTitle("调整任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("返回") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("无法保存", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .onAppear {
                memberID = task.assignee?.id
                scheduledDate = task.scheduledDate
                isCancelled = task.status == .cancelled
                cancellationReason = task.status == .cancelled ? (task.adjustmentNote ?? "") : ""
            }
        }
    }

    private var canSave: Bool {
        if isCancelled { return !cancellationReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return memberID != nil
    }

    private func save() {
        let member = members.first { $0.id == memberID }
        do {
            try RotationViewModel(context: context).adjust(
                task,
                assignee: member,
                scheduledDate: scheduledDate,
                cancellationReason: isCancelled ? cancellationReason : nil
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
