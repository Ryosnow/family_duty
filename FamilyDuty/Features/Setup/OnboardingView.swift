import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var memberName = ""
    @State private var firstRuleTitle = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("欢迎使用家庭值日")
                        .font(.largeTitle.bold())
                    Text("先建立一名家庭成员和第一项固定值日。")
                        .foregroundStyle(.secondary)
                }
                Section("家庭成员") {
                    TextField("成员姓名", text: $memberName)
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
        !memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !firstRuleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func finish() {
        let member = FamilyMember(
            name: memberName.trimmingCharacters(in: .whitespacesAndNewlines),
            sortOrder: 0
        )
        context.insert(member)
        do {
            try RotationViewModel(context: context).saveRule(
                title: firstRuleTitle,
                weekday: Calendar.current.component(.weekday, from: .now),
                startOfRotationWeek: .now,
                participants: [member],
                isEnabled: true,
                generateThrough: Calendar.current.date(byAdding: .weekOfYear, value: 4, to: .now) ?? .now
            )
        } catch {
            context.delete(member)
            errorMessage = error.localizedDescription
        }
    }
}
