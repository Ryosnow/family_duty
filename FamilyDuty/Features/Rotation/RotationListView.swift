import SwiftData
import SwiftUI

struct RotationListView: View {
    @Query(sort: \ChoreRule.title) private var rules: [ChoreRule]
    @State private var editingRule: ChoreRule?
    @State private var isAddingRule = false

    var body: some View {
        NavigationStack {
            List {
                if rules.isEmpty {
                    ContentUnavailableView("还没有固定轮班", systemImage: "arrow.triangle.2.circlepath", description: Text("添加一项固定值日开始安排。"))
                }
                ForEach(rules) { rule in
                    Button { editingRule = rule } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.title).font(.headline)
                            Text(summary(for: rule)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("固定轮班")
            .toolbar {
                Button("新增", systemImage: "plus") { isAddingRule = true }
                    .accessibilityIdentifier("rotation-add-rule")
            }
            .sheet(isPresented: $isAddingRule) { RuleEditorView(rule: nil) }
            .sheet(item: $editingRule) { rule in RuleEditorView(rule: rule) }
        }
    }

    private func summary(for rule: ChoreRule) -> String {
        guard rule.isEnabled else { return "已停用" }
        let assignee = RotationScheduler().assignee(for: rule, weekOf: .now, calendar: .current)
        return "下一位：\(assignee?.name ?? "尚未安排")"
    }
}
