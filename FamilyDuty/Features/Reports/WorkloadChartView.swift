import Charts
import SwiftUI

struct WorkloadChartView: View {
    let summaries: [MemberWorkloadSummary]

    private let chartColors: [Color] = [
        FamilyDutyTheme.fern,
        FamilyDutyTheme.sunflower,
        FamilyDutyTheme.lavender,
        FamilyDutyTheme.coral
    ]

    var body: some View {
        if summaries.isEmpty {
            FamilyDutyEmptyState(
                title: "暂无完成记录",
                message: "完成任务后，这里会显示每个人的工作量。",
                symbolName: "chart.bar.xaxis"
            )
        } else {
            Chart {
                ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                    BarMark(
                        x: .value("得分", summary.totalScore),
                        y: .value("成员", summary.memberName)
                    )
                    .foregroundStyle(chartColors[index % chartColors.count])
                    .cornerRadius(8)
                    .annotation(position: .trailing, alignment: .center, spacing: 8) {
                        Text("\(summary.totalScore)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(FamilyDutyTheme.ink)
                    }
                }
            }
            .chartXScale(domain: 0...maxScore)
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3]))
                        .foregroundStyle(FamilyDutyTheme.separator.opacity(0.45))
                    AxisValueLabel()
                        .foregroundStyle(FamilyDutyTheme.secondaryInk)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .foregroundStyle(FamilyDutyTheme.secondaryInk)
                }
            }
            .chartLegend(.hidden)
            .frame(height: chartHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("成员工作量图表")
            .accessibilityValue(accessibilityValue)
        }
    }

    private var maxScore: Int {
        max(summaries.map(\.totalScore).max() ?? 1, 1)
    }

    private var chartHeight: CGFloat {
        max(CGFloat(summaries.count) * 42, 128)
    }

    private var accessibilityValue: String {
        summaries
            .map { "\($0.memberName)完成\($0.completedCount)项，\($0.totalScore)分" }
            .joined(separator: "；")
    }
}
