import SwiftData
import SwiftUI

struct ClaimTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FamilyMember.sortOrder) private var members: [FamilyMember]
    let task: ChoreTask
    @State private var memberID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("领取人", selection: $memberID) {
                    ForEach(members) { member in
                        Text(member.name).tag(Optional(member.id))
                    }
                }
            }
            .navigationTitle("领取“\(task.title)”")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认领取") { claim() }.disabled(memberID == nil)
                }
            }
            .onAppear { memberID = members.first?.id }
            .alert("无法领取", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    private func claim() {
        guard let member = members.first(where: { $0.id == memberID }) else { return }
        do {
            try TemporaryTaskViewModel(context: context).claim(task, by: member)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
