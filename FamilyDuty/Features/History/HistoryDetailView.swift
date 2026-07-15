import SwiftUI

struct HistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recreationDraft: TemporaryTaskDraft?

    let record: CompletionRecord
    let calendar: Calendar

    private var task: ChoreTask? { record.task }
    private var taskTitle: String { task?.title ?? "已删除任务" }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务") {
                    LabeledContent("名称") {
                        TaskTitleView(title: taskTitle)
                    }
                    LabeledContent("类型", value: task?.isTemporary == true ? "临时任务" : "固定轮班")
                    if let task {
                        LabeledContent("原负责人", value: task.assignee?.name ?? "待领取")
                        LabeledContent("计划日期", value: task.scheduledDate.formatted(date: .long, time: .omitted))
                        LabeledContent("截止日期", value: TaskDeadlineService.effectiveDeadline(for: task, calendar: calendar).formatted(date: .long, time: .omitted))
                        if let note = task.adjustmentNote, !note.isEmpty {
                            LabeledContent("调整原因", value: note)
                        }
                    }
                }

                Section("完成情况") {
                    LabeledContent("实际完成人", value: HistoryViewModel.displayName(for: record))
                    LabeledContent("完成时间", value: record.completedAt.formatted(date: .long, time: .shortened))
                    LabeledContent("计划工作日", value: record.workDate.formatted(date: .long, time: .omitted))
                    LabeledContent("得分", value: "\(record.score) 分")
                }

                if let draft = HistoryViewModel.recreationDraft(for: record) {
                    Section {
                        Button("重新创建类似任务", systemImage: "plus.circle") {
                            recreationDraft = draft
                        }
                        .frame(minHeight: FamilyDutyTheme.minimumHitSize, alignment: .leading)
                        .accessibilityIdentifier("history-recreate")
                    } footer: {
                        Text("将复制任务名称和分值，并创建一项新的临时任务。")
                    }
                }
            }
            .navigationTitle("完成详情")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("history-detail")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: $recreationDraft) { draft in
                TemporaryTaskEditorView(initialDraft: draft)
            }
        }
    }
}
