import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \CompletionRecord.completedAt, order: .reverse) private var records: [CompletionRecord]
    @Query(sort: \FamilyMember.sortOrder) private var members: [FamilyMember]
    @State private var filter = HistoryFilter()
    @State private var customStartDate = Date.now
    @State private var customEndDate = Date.now
    @State private var selectedRecord: CompletionRecord?

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    private var visibleRecords: [CompletionRecord] {
        HistoryViewModel.filteredRecords(
            from: records,
            filter: filter,
            calendar: calendar,
            now: .now
        )
    }

    private var memberFilters: [HistoryMemberFilter] {
        var result: [HistoryMemberFilter] = [.all]
        result.append(contentsOf: members.map { .member($0.id) })

        let historicalNames = records
            .filter { $0.completedBy == nil }
            .compactMap(\.completedByName)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .reduce(into: [String]()) { names, name in
                if !names.contains(name) { names.append(name) }
            }
        result.append(contentsOf: historicalNames.map { HistoryMemberFilter.historicalName($0) })
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                filterSection

                if visibleRecords.isEmpty {
                    ContentUnavailableView(
                        records.isEmpty ? "还没有完成记录" : "没有匹配的完成记录",
                        systemImage: records.isEmpty ? "clock.arrow.circlepath" : "line.3.horizontal.decrease.circle",
                        description: Text(records.isEmpty ? "完成任务后，历史记录会显示在这里" : "尝试清除筛选条件或修改搜索词")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section("完成记录（(visibleRecords.count)）") {
                        ForEach(visibleRecords) { record in
                            Button {
                                selectedRecord = record
                            } label: {
                                historyRow(record)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("history-record-\(record.id.uuidString)")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier("history-view")
            .navigationTitle("历史")
            .searchable(text: $filter.titleQuery, prompt: "搜索任务名称")
            .accessibilityIdentifier("history-search-field")
            .sheet(item: $selectedRecord) { record in
                HistoryDetailView(record: record, calendar: calendar)
            }
        }
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .environment(\.calendar, calendar)
    }

    private var filterSection: some View {
        Section {
            HStack(spacing: 10) {
                dateFilterMenu
                memberFilterMenu
                Spacer(minLength: 0)
                if filter != HistoryFilter() {
                    Button("清除", systemImage: "xmark.circle") {
                        resetFilters()
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(FamilyDutyTheme.forest)
                    .accessibilityLabel("清除历史筛选")
                    .accessibilityIdentifier("history-clear-filters")
                }
            }
            .frame(minHeight: FamilyDutyTheme.minimumHitSize)

            if case .custom = filter.dateScope {
                DatePicker("开始日期", selection: $customStartDate, displayedComponents: .date)
                    .onChange(of: customStartDate) { _, _ in updateCustomDateFilter() }
                DatePicker("结束日期", selection: $customEndDate, displayedComponents: .date)
                    .onChange(of: customEndDate) { _, _ in updateCustomDateFilter() }
            }
        } header: {
            Text("筛选历史")
                .accessibilityIdentifier("history-filter-header")
        }
        .accessibilityIdentifier("history-filters")
    }

    private var dateFilterMenu: some View {
        Menu {
            Button("全部日期") { filter.dateScope = .all }
            Button("今天") { filter.dateScope = .today }
            Button("最近 7 天") { filter.dateScope = .lastSevenDays }
            Button("本月") { filter.dateScope = .thisMonth }
            Button("自定义日期") {
                filter.dateScope = .custom(start: customStartDate, end: customEndDate)
            }
        } label: {
            Label(filter.dateScope.title, systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityLabel("历史日期筛选：\(filter.dateScope.title)")
        .accessibilityIdentifier("history-date-filter")
    }

    private var memberFilterMenu: some View {
        Menu {
            ForEach(memberFilters) { memberFilter in
                Button(memberFilterTitle(for: memberFilter)) {
                    filter.member = memberFilter
                }
            }
        } label: {
            Label(memberFilterTitle(for: filter.member), systemImage: "person")
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityLabel("历史完成人筛选：\(memberFilterTitle(for: filter.member))")
        .accessibilityIdentifier("history-member-filter")
    }

    private func historyRow(_ record: CompletionRecord) -> some View {
        let taskTitle = record.task?.title ?? "已删除任务"
        return HStack(alignment: .top, spacing: 12) {
            FamilyDutyIconBadge(symbolName: "checkmark", tint: FamilyDutyTheme.fern, accessibilityLabel: "已完成", size: 38)
            VStack(alignment: .leading, spacing: 5) {
                TaskTitleView(title: taskTitle)
                    .font(.headline)
                    .foregroundStyle(FamilyDutyTheme.ink)
                Text("\(HistoryViewModel.displayName(for: record)) · \(record.completedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(FamilyDutyTheme.secondaryInk)
                Text("计划日：\(record.workDate.formatted(date: .abbreviated, time: .omitted)) · \(record.score) 分")
                    .font(.caption)
                    .foregroundStyle(FamilyDutyTheme.secondaryInk)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(FamilyDutyTheme.secondaryInk)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityLabel("\(taskTitle)，\(HistoryViewModel.displayName(for: record))完成，完成时间\(record.completedAt.formatted(date: .abbreviated, time: .shortened))，得分\(record.score)")
    }

    private func memberFilterTitle(for filter: HistoryMemberFilter) -> String {
        switch filter {
        case .all: "全部成员"
        case let .member(id): members.first { $0.id == id }?.name ?? "已删除成员"
        case let .historicalName(name): name
        }
    }

    private func updateCustomDateFilter() {
        filter.dateScope = .custom(start: customStartDate, end: customEndDate)
    }

    private func resetFilters() {
        filter = HistoryFilter()
        customStartDate = .now
        customEndDate = .now
    }
}
