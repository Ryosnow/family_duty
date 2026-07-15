import SwiftData
import SwiftUI

struct TaskBoardView: View {
    @Query private var tasks: [ChoreTask]
    @Query(sort: \CompletionRecord.completedAt, order: .reverse) private var records: [CompletionRecord]
    @State private var completing: ChoreTask?
    @State private var adjusting: ChoreTask?
    @State private var claiming: ChoreTask?

    private var sections: TaskBoardSections {
        TaskBoardViewModel.sections(from: tasks, records: records)
    }

    private var taskCount: Int {
        sections.pending.count + sections.completed.count + sections.cancelled.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 6) {
                        Text("📋")
                            .accessibilityHidden(true)
                        Text("今天共 \(taskCount) 项任务")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                taskSection(title: "待处理", tasks: sections.pending) { task in
                    Button {
                        if task.assignee == nil { claiming = task } else { completing = task }
                    } label: {
                        taskRow(task)
                    }
                    .accessibilityHint(task.assignee == nil ? "打开领取页面" : "打开完成确认")
                    .swipeActions {
                        Button("调整") { adjusting = task }
                            .tint(.orange)
                    }
                }

                taskSection(title: "已完成", tasks: sections.completed) { task in
                    completedTaskRow(task)
                }

                taskSection(title: "已取消", tasks: sections.cancelled) { task in
                    cancelledTaskRow(task)
                }
            }
            .navigationTitle("任务面板")
            .accessibilityIdentifier("task-board")
            .overlay {
                if taskCount == 0 {
                    ContentUnavailableView("今天没有任务", systemImage: "checklist", description: Text("今天的任务会显示在这里"))
                }
            }
            .sheet(item: $completing) { task in CompletionSheet(task: task) }
            .sheet(item: $adjusting) { task in TaskAdjustmentSheet(task: task) }
            .sheet(item: $claiming) { task in ClaimTaskSheet(task: task) }
        }
    }

    @ViewBuilder
    private func taskSection<Content: View>(
        title: String,
        tasks: [ChoreTask],
        @ViewBuilder content: @escaping (ChoreTask) -> Content
    ) -> some View {
        Section {
            if tasks.isEmpty {
                Text("暂无任务").foregroundStyle(.secondary)
            } else {
                ForEach(tasks) { task in
                    content(task)
                        .accessibilityIdentifier("task-board-task-\(task.title)")
                    }
                }
        } header: {
            HStack(spacing: 6) {
                Text(sectionEmoji(for: title))
                    .accessibilityHidden(true)
                Text(title)
            }
        }
    }

    private func sectionEmoji(for title: String) -> String {
        switch title {
        case "待处理": "⏳"
        case "已完成": "✅"
        case "已取消": "🚫"
        default: "📋"
        }
    }

    @ViewBuilder
    private func taskRow(_ task: ChoreTask) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if TaskDeadlineService.isOverdue(task, now: .now, calendar: .current) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .accessibilityLabel("已逾期")
                    .accessibilityIdentifier("task-board-overdue-\(task.title)")
                    .padding(.top, 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                TaskTitleView(title: task.title)
                    .font(.headline)
                Text(task.assignee?.name ?? "待领取").foregroundStyle(.secondary)
                taskMetadata(task)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private func completedTaskRow(_ task: ChoreTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                TaskTitleView(title: task.title)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
                .font(.headline)
                .foregroundStyle(.secondary)
            if let record = TaskBoardViewModel.latestCompletionRecord(for: task, from: records) {
                let completedByName = record.completedByName ?? record.completedBy?.name ?? "未知"
                Text("已完成 · \(completedByName) · \(record.completedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("已完成 · 暂无完成记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(task.scheduledDate, format: .dateTime.weekday().month().day())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private func cancelledTaskRow(_ task: ChoreTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                TaskTitleView(title: task.title)
            } icon: {
                Image(systemName: "xmark.circle.fill")
            }
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("已取消")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let note = task.adjustmentNote, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private func taskMetadata(_ task: ChoreTask) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(task.scheduledDate, format: .dateTime.weekday().month().day())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("最晚：\(TaskDeadlineService.effectiveDeadline(for: task, calendar: .current), format: .dateTime.year().month().day())")
                .font(.caption)
                .foregroundStyle(TaskDeadlineService.isOverdue(task, now: .now, calendar: .current) ? .red : .secondary)
        }
    }
}
