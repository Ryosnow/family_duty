import SwiftData
import SwiftUI

struct MemberEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var members: [FamilyMember]
    let member: FamilyMember?
    @State private var name = ""
    @State private var colorName = FamilyDutyMemberColor.defaultName(forSortOrder: 0)
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("成员") {
                    TextField("姓名", text: $name)
                    Picker("识别颜色", selection: $colorName) {
                        ForEach(FamilyDutyMemberColor.options) { option in
                            Label(option.title, systemImage: "circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(option.color)
                                .tag(option.name)
                        }
                    }
                }
            }
                .navigationTitle(member == nil ? "新增成员" : "编辑成员")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { save() }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .onAppear {
                    name = member?.name ?? ""
                    colorName = member?.colorName ?? FamilyDutyMemberColor.defaultName(forSortOrder: members.count)
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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let member {
            member.name = trimmedName
            member.colorName = FamilyDutyMemberColor.colorName(for: colorName)
        } else {
            context.insert(
                FamilyMember(
                    name: trimmedName,
                    colorName: FamilyDutyMemberColor.colorName(for: colorName),
                    sortOrder: members.count
                )
            )
        }
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
