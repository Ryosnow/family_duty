import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var tasks: [ChoreTask]
    @Query(sort: \CompletionRecord.completedAt, order: .reverse) private var records: [CompletionRecord]
    @State private var completing: ChoreTask?
    @State private var quickCompleting: ChoreTask?
    @State private var isShowingQuickCompletionConfirmation = false
    @State private var quickCompletionErrorMessage: String?
    @State private var adjusting: ChoreTask?
    @State private var claiming: ChoreTask?
    @State private var isAddingTemporaryTask = false

    private var todayPendingTasks: [ChoreTask] {
        DashboardViewModel.todayTasks(from: tasks)
    }

    private var todayProgressSummary: (completed: Int, total: Int) {
        DashboardViewModel.todayProgress(from: tasks)
    }

    private var todayCompletedCount: Int {
        todayProgressSummary.completed
    }

    private var todayTotalCount: Int {
        todayProgressSummary.total
    }

    private var todayProgress: Double {
        guard todayTotalCount > 0 else { return 0 }
        return Double(todayCompletedCount) / Double(todayTotalCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FamilyDutyTheme.sectionSpacing) {
                    todayProgressHeader

                    if !DashboardViewModel.overdueTasks(from: tasks).isEmpty {
                        taskSection(
                            title: "已逾期",
                            symbolName: "clock.badge.exclamationmark",
                            tint: FamilyDutyTheme.coral,
                            tasks: DashboardViewModel.overdueTasks(from: tasks),
                            emptyMessage: "没有逾期任务"
                        )
                    }

                    taskSection(
                        title: "今天",
                        symbolName: "calendar",
                        tint: FamilyDutyTheme.forest,
                        tasks: todayPendingTasks,
                        emptyMessage: "今天没有待办"
                    )
                    taskSection(
                        title: "本周稍后",
                        symbolName: "calendar.badge.clock",
                        tint: FamilyDutyTheme.fern,
                        tasks: DashboardViewModel.laterThisWeekTasks(from: tasks),
                        emptyMessage: "本周没有更多待办"
                    )
                    taskSection(
                        title: "临时任务",
                        symbolName: "sparkles",
                        tint: FamilyDutyTheme.sunflower,
                        tasks: DashboardViewModel.temporaryTasks(from: tasks),
                        emptyMessage: "还没有临时任务"
                    )
                    recentHistory
                }
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, FamilyDutyTheme.pagePadding)
                .padding(.vertical, 24)
            }
            .background(FamilyDutyTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("家庭值日")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                Button("新增临时任务", systemImage: "plus") { isAddingTemporaryTask = true }
                        .accessibilityIdentifier("dashboard-add-temporary-toolbar")
                }
            }
            .sheet(item: $completing) { task in CompletionSheet(task: task) }
            .sheet(item: $adjusting) { task in TaskAdjustmentSheet(task: task) }
            .sheet(item: $claiming) { task in ClaimTaskSheet(task: task) }
            .sheet(isPresented: $isAddingTemporaryTask) { TemporaryTaskEditorView() }
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

    private var todayProgressHeader: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                Text("今天一起把家照顾好")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(todayTotalCount == 0 ? "先安排一项值日，今天就有小目标了。" : "每个人出一点力，家里就会更轻松。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                Button("新增临时任务", systemImage: "plus") { isAddingTemporaryTask = true }
                    .buttonStyle(.borderedProminent)
                    .tint(FamilyDutyTheme.sunflower)
                    .foregroundStyle(FamilyDutyTheme.forest)
                    .frame(minHeight: FamilyDutyTheme.minimumHitSize)
                    .accessibilityIdentifier("dashboard-add-temporary")
            }
            Spacer(minLength: 0)
            FamilyDutyProgressRing(
                progress: todayProgress,
                completed: todayCompletedCount,
                total: todayTotalCount
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FamilyDutyTheme.forest, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(FamilyDutyTheme.mint.opacity(0.18))
                .frame(width: 130, height: 130)
                .offset(x: 38, y: -54)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityIdentifier("dashboard-progress-card")
    }

    @ViewBuilder
    private func taskSection(
        title: String,
        symbolName: String,
        tint: Color,
        tasks: [ChoreTask],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FamilyDutySectionHeader(title: title, symbolName: symbolName, tint: tint, count: tasks.isEmpty ? nil : tasks.count)
            if tasks.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(FamilyDutyTheme.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, FamilyDutyTheme.cardPadding)
                    .frame(minHeight: FamilyDutyTheme.minimumHitSize)
                    .familyDutyCard(cornerRadius: FamilyDutyTheme.compactCornerRadius)
            } else {
                ForEach(tasks) { task in
                    HStack(spacing: 8) {
                        Button {
                            if task.assignee == nil { claiming = task } else { completing = task }
                        } label: {
                            FamilyDutyTaskCard(
                                title: TaskPresetCatalog.titleWithoutKnownEmoji(for: task.title),
                                assignee: task.assignee?.name ?? "待领取",
                                metadata: task.scheduledDate.formatted(date: .abbreviated, time: .omitted),
                                deadline: "最晚：\(TaskDeadlineService.effectiveDeadline(for: task, calendar: .current).formatted(date: .abbreviated, time: .omitted))",
                                symbolName: TaskPresetCatalog.symbolName(for: task.title),
                                accent: tint,
                                memberTint: task.assignee.map { FamilyDutyMemberColor.color(for: $0.colorName) },
                                statusTitle: task.assignee == nil ? "待领取" : nil,
                                statusSymbolName: task.assignee == nil ? "hand.tap" : nil,
                                statusTint: FamilyDutyTheme.sunflower,
                                isOverdue: TaskDeadlineService.isOverdue(task, now: .now, calendar: .current)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(DashboardViewModel.accessibilityLabel(for: task))
                        .accessibilityHint(task.assignee == nil ? "打开领取页面" : "打开完成确认")
                        .accessibilityIdentifier("dashboard-task-\(task.id.uuidString)")
                        if task.assignee != nil {
                            Button("快速完成", systemImage: "checkmark.circle.fill") {
                                quickCompleting = task
                                isShowingQuickCompletionConfirmation = true
                            }
                            .labelStyle(.iconOnly)
                            .font(.title2)
                            .foregroundStyle(FamilyDutyTheme.fern)
                            .frame(width: FamilyDutyTheme.minimumHitSize, height: FamilyDutyTheme.minimumHitSize)
                            .accessibilityIdentifier("dashboard-quick-complete-\(task.id.uuidString)")
                        }
                    }
                    .swipeActions {
                        Button("调整") { adjusting = task }
                            .tint(FamilyDutyTheme.sunflower)
                    }
                }
            }
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

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            FamilyDutySectionHeader(title: "近期完成", symbolName: "checkmark.circle", tint: FamilyDutyTheme.fern, count: records.isEmpty ? nil : min(records.count, 8))
            if records.isEmpty {
                Text("还没有完成记录")
                    .font(.subheadline)
                    .foregroundStyle(FamilyDutyTheme.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, FamilyDutyTheme.cardPadding)
                    .frame(minHeight: FamilyDutyTheme.minimumHitSize)
                    .familyDutyCard(cornerRadius: FamilyDutyTheme.compactCornerRadius)
            } else {
                ForEach(records.prefix(8)) { record in
                    let completedByName = record.completedByName ?? record.completedBy?.name ?? "未知"
                    HStack(alignment: .center, spacing: 12) {
                        FamilyDutyIconBadge(symbolName: "checkmark", tint: FamilyDutyTheme.fern, accessibilityLabel: "已完成", size: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(TaskPresetCatalog.titleWithoutKnownEmoji(for: record.task?.title ?? "值日"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FamilyDutyTheme.ink)
                            Text("\(completedByName) · \(record.completedAt.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(FamilyDutyTheme.secondaryInk)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(FamilyDutyTheme.cardPadding)
                    .familyDutyCard(cornerRadius: FamilyDutyTheme.compactCornerRadius)
                    .accessibilityIdentifier("history-\(record.id.uuidString)")
                }
            }
        }
    }
}
