import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FamilyMember.sortOrder) private var members: [FamilyMember]
    @State private var editingMember: FamilyMember?
    @State private var isAddingMember = false
    @State private var deletionMessage: String?
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("家庭成员") {
                    ForEach(members) { member in
                        Button(member.name) { editingMember = member }
                            .swipeActions {
                                Button("删除", role: .destructive) { delete(member) }
                            }
                    }
                    .onMove(perform: move)
                }
                Section("提醒") {
                    NavigationLink("通知设置") { NotificationSettingsView() }
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("新增成员", systemImage: "person.badge.plus") { isAddingMember = true }
                        .accessibilityIdentifier("settings-add-member")
                }
                ToolbarItem(placement: .secondaryAction) { EditButton() }
            }
            .sheet(isPresented: $isAddingMember) { MemberEditorView(member: nil) }
            .sheet(item: $editingMember) { member in MemberEditorView(member: member) }
            .alert("暂时不能删除", isPresented: Binding(
                get: { deletionMessage != nil },
                set: { if !$0 { deletionMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(deletionMessage ?? "")
            }
            .alert("无法保存", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "未知错误")
            }
        }
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var reordered = members
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, member) in reordered.enumerated() { member.sortOrder = index }
        do {
            try context.save()
        } catch {
            context.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }

    private func delete(_ member: FamilyMember) {
        do {
            try MemberDeletionService(context: context).delete(member)
        } catch {
            deletionMessage = error.localizedDescription
        }
    }
}
