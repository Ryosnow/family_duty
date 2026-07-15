import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var memberDrafts = [
        OnboardingMemberDraft(colorName: FamilyDutyMemberColor.defaultName(forSortOrder: 0))
    ]
    @State private var firstRuleTitle = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("欢迎使用家庭值日")
                        .font(.largeTitle.bold())
                    Text("先建立家庭成员和第一项固定值日。")
                        .foregroundStyle(.secondary)
                }
                Section("家庭成员") {
                    ForEach($memberDrafts) { $draft in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("成员姓名", text: $draft.name)
                            HStack {
                                Picker("识别颜色", selection: $draft.colorName) {
                                    ForEach(FamilyDutyMemberColor.options) { option in
                                        Label(option.title, systemImage: "circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(option.color)
                                            .tag(option.name)
                                    }
                                }
                                .accessibilityLabel("成员颜色")
                                if memberDrafts.count > 1 {
                                    Button("删除成员", systemImage: "minus.circle", role: .destructive) {
                                        memberDrafts.removeAll { $0.id == draft.id }
                                    }
                                    .labelStyle(.iconOnly)
                                    .accessibilityLabel("删除成员")
                                }
                            }
                        }
                        .accessibilityIdentifier("onboarding-member-\(draft.id.uuidString)")
                    }
                    Button("添加成员", systemImage: "plus") {
                        memberDrafts.append(
                            OnboardingMemberDraft(
                                colorName: FamilyDutyMemberColor.defaultName(forSortOrder: memberDrafts.count)
                            )
                        )
                    }
                    .accessibilityIdentifier("onboarding-add-member")
                }
                Section("首个轮班") {
                    TextField("首个固定任务", text: $firstRuleTitle)
                }
                Button("开始使用") { finish() }
                    .disabled(!canFinish)
            }
            .navigationTitle("开始设置")
            .alert("无法完成设置", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    private var canFinish: Bool {
        !memberDrafts.isEmpty &&
        memberDrafts.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        !firstRuleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func finish() {
        do {
            try OnboardingViewModel(context: context).finish(
                memberDrafts: memberDrafts,
                firstRuleTitle: firstRuleTitle
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
