import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query private var tasks: [ChoreTask]
    @Query(sort: \CompletionRecord.completedAt, order: .reverse) private var records: [CompletionRecord]
    @State private var completing: ChoreTask?
    @State private var adjusting: ChoreTask?
    @State private var claiming: ChoreTask?
    @State private var isAddingTemporaryTask = false

    var body: some View {
        NavigationStack {
            List {
                let overdueTasks = DashboardViewModel.overdueTasks(from: tasks)
                if !overdueTasks.isEmpty {
                    taskSection(
                        title: "已逾期",
                        tasks: overdueTasks,
                        emptyMessage: "没有逾期任务"
                    )
                }
                taskSection(
                    title: "今天",
                    tasks: DashboardViewModel.todayTasks(from: tasks),
                    emptyMessage: "今天没有待办"
                )
                taskSection(
                    title: "本周稍后",
                    tasks: DashboardViewModel.laterThisWeekTasks(from: tasks),
                    emptyMessage: "本周没有更多待办"
                )
                taskSection(
                        title: "临时任务",
                    tasks: DashboardViewModel.temporaryTasks(from: tasks),
                    emptyMessage: "还没有临时任务"
                )
                Section {
                    if records.isEmpty {
                        Text("还没有完成记录").foregroundStyle(.secondary)
                    } else {
                        ForEach(records.prefix(8)) { record in
                            let completedByName = record.completedByName ?? record.completedBy?.name ?? "未知"
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                TaskTitleView(title: record.task?.title ?? "值日")
                                Text("· \(completedByName) · \(record.completedAt.formatted(date: .omitted, time: .shortened))")
                                    .foregroundStyle(.secondary)
                            }
                                .accessibilityIdentifier("history-\(record.task?.title ?? "值日")-by-\(completedByName)")
                            }
                        }
                } header: {
                    sectionHeader(title: "近期完成")
                }
            }
            .navigationTitle("家庭值日")
            .toolbar {
                Button("新增临时任务", systemImage: "plus") { isAddingTemporaryTask = true }
                    .accessibilityIdentifier("dashboard-add-temporary")
            }
            .sheet(item: $completing) { task in CompletionSheet(task: task) }
            .sheet(item: $adjusting) { task in TaskAdjustmentSheet(task: task) }
            .sheet(item: $claiming) { task in ClaimTaskSheet(task: task) }
            .sheet(isPresented: $isAddingTemporaryTask) { TemporaryTaskEditorView() }
        }
    }

    @ViewBuilder
    private func taskSection(title: String, tasks: [ChoreTask], emptyMessage: String) -> some View {
        Section {
            if tasks.isEmpty {
                Text(emptyMessage).foregroundStyle(.secondary)
            } else {
                ForEach(tasks) { task in
                    Button {
                        if task.assignee == nil { claiming = task } else { completing = task }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            if TaskDeadlineService.isOverdue(task, now: .now, calendar: .current) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 10, height: 10)
                                    .accessibilityLabel("已逾期")
                                    .accessibilityIdentifier("task-overdue-indicator-\(task.title)")
                                    .padding(.top, 6)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                TaskTitleView(title: task.title)
                                    .font(.headline)
                                Text(task.assignee?.name ?? "待领取").foregroundStyle(.secondary)
                                Text(task.scheduledDate, format: .dateTime.weekday().month().day())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("最晚：\(TaskDeadlineService.effectiveDeadline(for: task, calendar: .current), format: .dateTime.year().month().day())")
                                    .font(.caption)
                                    .foregroundStyle(TaskDeadlineService.isOverdue(task, now: .now, calendar: .current) ? .red : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityLabel(DashboardViewModel.accessibilityLabel(for: task))
                    .accessibilityHint(task.assignee == nil ? "打开领取页面" : "打开完成确认")
                    .accessibilityIdentifier("dashboard-task-\(task.title)")
                    .swipeActions {
                        Button("调整") { adjusting = task }
                            .tint(.orange)
                    }
                }
            }
        } header: {
            sectionHeader(title: title)
        }
    }

    private func sectionHeader(title: String) -> some View {
        HStack(spacing: 6) {
            Text(sectionEmoji(for: title))
                .accessibilityHidden(true)
            Text(title)
        }
    }

    private func sectionEmoji(for title: String) -> String {
        switch title {
        case "已逾期": "⏰"
        case "今天": "📅"
        case "本周稍后": "🗓️"
        case "临时任务": "✨"
        case "近期完成": "✅"
        default: "📋"
        }
    }
}
