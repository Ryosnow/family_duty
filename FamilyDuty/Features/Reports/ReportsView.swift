import Charts
import SwiftData
import SwiftUI

struct ReportsView: View {
    @Query(sort: \FamilyMember.sortOrder) private var members: [FamilyMember]
    @Query private var tasks: [ChoreTask]
    @Query(sort: \CompletionRecord.completedAt, order: .reverse) private var records: [CompletionRecord]
    @State private var viewModel: ReportsViewModel
    private let now: Date

    init(initialPeriod: ReportPeriod = .day(.now), calendar: Calendar = .current, now: Date = .now) {
        _viewModel = State(initialValue: ReportsViewModel(initialPeriod: initialPeriod, calendar: calendar))
        self.now = now
    }

    private var summaries: [MemberWorkloadSummary] {
        ScoreReportViewModel.summaries(
            for: viewModel.period,
            members: members,
            records: records,
            calendar: viewModel.calendar
        )
    }

    private var dataPoints: [WorkloadDataPoint] {
        ScoreReportViewModel.dailyDataPoints(
            for: viewModel.period,
            records: records,
            calendar: viewModel.calendar
        )
    }

    private var plannedWorkloadSummaries: [PlannedWorkloadSummary] {
        PlannedWorkloadViewModel.weeklySummaries(
            for: now,
            tasks: tasks,
            members: members,
            calendar: viewModel.calendar
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FamilyDutyTheme.sectionSpacing) {
                    reportKindPicker
                    periodNavigator

                    PlannedWorkloadSummaryView(summaries: plannedWorkloadSummaries)

                    WorkloadSummaryView(title: "\(viewModel.reportKind.title)总览", summaries: summaries)

                    if viewModel.reportKind != .day {
                        trendSection
                    }
                }
                .padding(FamilyDutyTheme.pagePadding)
            }
            .scrollIndicators(.hidden)
            .background(FamilyDutyTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("报表")
            .accessibilityIdentifier("reports-view")
        }
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .environment(\.calendar, viewModel.calendar)
    }

    private var reportKindPicker: some View {
        HStack(spacing: 4) {
            ForEach(ReportKind.allCases) { kind in
                Button {
                    viewModel.select(kind)
                } label: {
                    Text(kind.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewModel.reportKind == kind ? FamilyDutyTheme.forest : FamilyDutyTheme.secondaryInk)
                        .frame(maxWidth: .infinity, minHeight: FamilyDutyTheme.minimumHitSize)
                        .background(
                            viewModel.reportKind == kind ? FamilyDutyTheme.cardBackground : .clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.reportKind == kind ? .isSelected : [])
            }
        }
        .padding(4)
        .background(FamilyDutyTheme.surface, in: Capsule())
        .overlay {
            Capsule()
                .stroke(FamilyDutyTheme.separator.opacity(0.45), lineWidth: 0.8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("报表周期")
        .accessibilityIdentifier("reports-period-picker")
    }

    private var periodNavigator: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.move(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.bold))
                    .foregroundStyle(FamilyDutyTheme.forest)
                    .frame(width: FamilyDutyTheme.minimumHitSize, height: FamilyDutyTheme.minimumHitSize)
                    .background(FamilyDutyTheme.mint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("上一个\(viewModel.reportKind.title)")
            .accessibilityIdentifier("reports-previous-period")

            VStack(spacing: 4) {
                Text(viewModel.periodTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(FamilyDutyTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text("选择日期查看历史")
                    .font(.caption)
                    .foregroundStyle(FamilyDutyTheme.secondaryInk)
            }
            .frame(maxWidth: .infinity)

            DatePicker(
                "查看日期",
                selection: $viewModel.anchorDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(FamilyDutyTheme.forest)
            .accessibilityLabel("当前报表日期")
            .accessibilityIdentifier("reports-period-title")

            Button {
                viewModel.move(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(FamilyDutyTheme.forest)
                    .frame(width: FamilyDutyTheme.minimumHitSize, height: FamilyDutyTheme.minimumHitSize)
                    .background(FamilyDutyTheme.mint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下一个\(viewModel.reportKind.title)")
            .accessibilityIdentifier("reports-next-period")
        }
        .padding(12)
        .familyDutyCard(cornerRadius: 16)
    }

    @ViewBuilder
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label("每日趋势", systemImage: "chart.xyaxis.line")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(FamilyDutyTheme.ink)
                Spacer()
                Text("按计划工作日")
                    .font(.caption)
                    .foregroundStyle(FamilyDutyTheme.secondaryInk)
            }

            if dataPoints.isEmpty {
                FamilyDutyEmptyState(
                    title: "暂无趋势数据",
                    message: "这个周期还没有完成记录。",
                    symbolName: "chart.xyaxis.line"
                )
            } else {
                Chart {
                    ForEach(dataPoints) { point in
                        LineMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("得分", point.totalScore)
                        )
                        .foregroundStyle(by: .value("成员", point.memberName))
                        .symbol(by: .value("成员", point.memberName))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("得分", point.totalScore)
                        )
                        .foregroundStyle(by: .value("成员", point.memberName))
                    }
                }
                .chartYAxisLabel("得分")
                .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(FamilyDutyTheme.surface.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .frame(height: 190)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("每日工作量趋势图")
                .accessibilityValue(
                    dataPoints
                        .map { "\($0.date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN"))))，\($0.memberName) \($0.totalScore)分" }
                        .joined(separator: "；")
                )
                .accessibilityIdentifier("reports-trend-chart")
            }
        }
        .padding(FamilyDutyTheme.cardPadding)
        .familyDutyCard()
    }
}
