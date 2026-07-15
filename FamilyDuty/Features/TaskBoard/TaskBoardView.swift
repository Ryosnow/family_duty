import SwiftData
import SwiftUI

struct TaskBoardView: View {
    @Environment(\.modelContext) private var context
    @Query private var tasks: [ChoreTask]
    @Query(sort: \FamilyMember.sortOrder) private var members: [FamilyMember]
    @Query(sort: \CompletionRecord.completedAt, order: .reverse) private var records: [CompletionRecord]
    @State private var completing: ChoreTask?
    @State private var quickCompleting: ChoreTask?
    @State private var isShowingQuickCompletionConfirmation = false
    @State private var quickCompletionErrorMessage: String?
    @State private var adjusting: ChoreTask?
    @State private var claiming: ChoreTask?
    @State private var undoing: ChoreTask?
    @State private var undoErrorMessage: String?

    private var sections: TaskBoardSections {
        TaskBoardViewModel.sections(from: tasks, records: records)
    }

    private var taskCount: Int {
        sections.pending.count + sections.completed.count + sections.cancelled.count
    }

    private var workloadSummaries: [MemberWorkloadSummary] {
        TaskBoardViewModel.todayWorkloadSummaries(
            from: records,
            members: members,
            now: .now,
            calendar: .current
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WorkloadSummaryView(title: "今日工作量", summaries: workloadSummaries)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("task-board-summary")

                    NavigationLink {
                        ReportsView()
                    } label: {
                        Label("查看历史报表", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FamilyDutyTheme.forest)
                            .frame(minHeight: FamilyDutyTheme.minimumHitSize, alignment: .leading)
                    }
                    .accessibilityIdentifier("task-board-history-reports")
                }

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
                    pendingTaskRow(task)
                }

                taskSection(title: "已完成", tasks: sections.completed) { task in
                    HStack(alignment: .top, spacing: 12) {
                        completedTaskRow(task)
                        Button("撤销完成", systemImage: "arrow.uturn.backward") {
                            undoing = task
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("task-board-undo-\(task.id.uuidString)")
                    }
                    .swipeActions {
                        Button("撤销完成", role: .destructive) { undoing = task }
                    }
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
            .alert("撤销完成？", isPresented: Binding(
                get: { undoing != nil },
                set: { if !$0 { undoing = nil } }
            )) {
                Button("撤销完成", role: .destructive) { undoCompletedTask() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("任务会回到待处理状态，并可重新选择实际完成人。")
            }
            .alert("无法撤销完成", isPresented: Binding(
                get: { undoErrorMessage != nil },
                set: { if !$0 { undoErrorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(undoErrorMessage ?? "未知错误")
            }
            .quickCompletionConfirmation(
                task: $quickCompleting,
                isPresented: $isShowingQuickCompletionConfirmation,
                onConfirm: completeQuickly
            )
            .alert("无法快速完成任务", isPresented: Binding(
                get: { quickCompletionErrorMessage != nil },
                set: { if !$0 { quickCompletionErrorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(quickCompletionErrorMessage ?? "未知错误")
            }
        }
    }

    private func undoCompletedTask() {
        guard let task = undoing else { return }
        do {
            try CompletionService(context: context).undoCompletion(task)
            undoing = nil
        } catch {
            undoing = nil
            undoErrorMessage = error.localizedDescription
        }
    }

    private func pendingTaskRow(_ task: ChoreTask) -> some View {
        HStack(spacing: 8) {
            Button {
                if task.assignee == nil { claiming = task } else { completing = task }
            } label: {
                taskRow(task)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(DashboardViewModel.accessibilityLabel(for: task))
            .accessibilityHint(task.assignee == nil ? "打开领取页面" : "打开完成确认")
            if task.assignee != nil {
                Button("快速完成", systemImage: "checkmark.circle.fill") {
                    quickCompleting = task
                    isShowingQuickCompletionConfirmation = true
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(FamilyDutyTheme.fern)
                .frame(width: FamilyDutyTheme.minimumHitSize, height: FamilyDutyTheme.minimumHitSize)
                .accessibilityIdentifier("task-board-quick-complete-\(task.id.uuidString)")
            }
        }
        .swipeActions {
            Button("调整") { adjusting = task }
                .tint(.orange)
        }
    }

    private func completeQuickly(_ task: ChoreTask) {
        guard let member = task.assignee else { return }
        do {
            try CompletionService(context: context).complete(task, by: member)
        } catch {
            quickCompletionErrorMessage = error.localizedDescription
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
                        .accessibilityIdentifier("task-board-task-\(task.id.uuidString)")
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
                    .accessibilityIdentifier("task-board-overdue-\(task.id.uuidString)")
                    .padding(.top, 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                TaskTitleView(title: task.title)
                    .font(.headline)
                FamilyDutyMemberChip(
                    name: task.assignee?.name ?? "待领取",
                    tint: task.assignee.map { FamilyDutyMemberColor.color(for: $0.colorName) } ?? FamilyDutyTheme.sunflower
                )
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
