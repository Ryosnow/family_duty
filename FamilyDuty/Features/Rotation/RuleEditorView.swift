import SwiftData
import SwiftUI

struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FamilyMember.sortOrder) private var members: [FamilyMember]

    let rule: ChoreRule?
    @State private var title = ""
    @State private var weekday = Calendar.current.component(.weekday, from: .now)
    @State private var startOfRotationWeek = Date.now
    @State private var participantIDs: [UUID] = []
    @State private var isEnabled = true
    @State private var scoreText = "1"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("固定值日") {
                    TextField("任务名称", text: $title)
                    Picker("星期", selection: $weekday) {
                        ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) { index, name in
                            Text(name).tag(index + 1)
                        }
                    }
                    DatePicker("轮换起始周", selection: $startOfRotationWeek, displayedComponents: .date)
                    TextField("得分", text: $scoreText)
                        .keyboardType(.numberPad)
                    Toggle("启用规则", isOn: $isEnabled)
                }

                Section("参与成员") {
                    ForEach(members) { member in
                        Toggle(member.name, isOn: participantBinding(for: member.id))
                    }
                    if !participantIDs.isEmpty {
                        NavigationLink("调整轮班顺序") {
                            MemberOrderEditorView(members: members, participantIDs: $participantIDs)
                        }
                    }
                }
            }
            .navigationTitle(rule == nil ? "新增轮班" : "编辑轮班")
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
            .onAppear(perform: loadRule)
        }
    }

    private func participantBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { participantIDs.contains(id) },
            set: { selected in
                if selected, !participantIDs.contains(id) { participantIDs.append(id) }
                if !selected { participantIDs.removeAll { $0 == id } }
            }
        )
    }

    private func loadRule() {
        guard let rule else { return }
        title = rule.title
        weekday = rule.weekday
        startOfRotationWeek = rule.startOfRotationWeek
        participantIDs = rule.participantOrder
        isEnabled = rule.isEnabled
        scoreText = String(rule.score)
    }

    private func save() {
        let participants = participantIDs.compactMap { id in members.first { $0.id == id } }
        let endDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: .now) ?? .now
        do {
            try RotationViewModel(context: context).saveRule(
                existingRule: rule,
                title: title,
                weekday: weekday,
                startOfRotationWeek: startOfRotationWeek,
                participants: participants,
                isEnabled: isEnabled,
                score: Int(scoreText) ?? 0,
                generateThrough: endDate
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
