import SwiftData
import SwiftUI

struct CompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let task: ChoreTask
    @Query private var members: [FamilyMember]
    @State private var memberID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("实际完成人", selection: $memberID) {
                    ForEach(members) { member in
                        HStack {
                            FamilyDutyMemberChip(
                                name: member.name,
                                tint: FamilyDutyMemberColor.color(for: member.colorName)
                            )
                            Spacer()
                        }
                        .tag(Optional(member.id))
                    }
                }
            }
            .navigationTitle("确认完成")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认完成") { complete() }.disabled(memberID == nil)
                }
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .onAppear { memberID = task.assignee?.id ?? members.first?.id }
            .alert("无法完成任务", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    private func complete() {
        guard let member = members.first(where: { $0.id == memberID }) else { return }
        do {
            try CompletionService(context: context).complete(task, by: member)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
