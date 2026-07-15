import SwiftUI

struct WorkloadSummaryView: View {
    let title: String
    let summaries: [MemberWorkloadSummary]

    private var totalCount: Int {
        summaries.reduce(0) { $0 + $1.completedCount }
    }

    private var totalScore: Int {
        summaries.reduce(0) { $0 + $1.totalScore }
    }

    init(title: String = "工作量", summaries: [MemberWorkloadSummary]) {
        self.title = title
        self.summaries = summaries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: "chart.bar.xaxis")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(FamilyDutyTheme.ink)
                Spacer()
            }

            HStack(spacing: 12) {
                WorkloadMetricView(title: "完成任务", value: "\(totalCount) 项", tint: FamilyDutyTheme.fern)
                WorkloadMetricView(title: "总得分", value: "\(totalScore) 分", tint: FamilyDutyTheme.forest)
            }

            Text("按完成得分比较每位成员的工作量")
                .font(.caption)
                .foregroundStyle(FamilyDutyTheme.secondaryInk)

            WorkloadChartView(summaries: summaries)

            VStack(spacing: 0) {
                ForEach(summaries) { summary in
                    HStack(spacing: 12) {
                        Text(summary.memberName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(FamilyDutyTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text("完成 \(summary.completedCount) 项")
                            .font(.caption)
                            .foregroundStyle(FamilyDutyTheme.secondaryInk)
                        Text("\(summary.totalScore) 分")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(FamilyDutyTheme.forest)
                    }
                    .frame(minHeight: FamilyDutyTheme.minimumHitSize)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(summary.memberName)，完成 \(summary.completedCount) 项，\(summary.totalScore) 分")

                    if summary.id != summaries.last?.id {
                        Divider()
                    }
                }
            }
            .accessibilityIdentifier("workload-summary-details")
        }
        .padding(FamilyDutyTheme.cardPadding)
        .familyDutyCard()
        .accessibilityIdentifier("workload-summary")
    }
}

private struct WorkloadMetricView: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(FamilyDutyTheme.secondaryInk)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
