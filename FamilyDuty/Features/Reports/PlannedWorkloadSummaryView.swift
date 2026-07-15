import SwiftUI

struct PlannedWorkloadSummaryView: View {
    let summaries: [PlannedWorkloadSummary]

    private var totalAssignedCount: Int {
        summaries.reduce(0) { $0 + $1.assignedCount }
    }

    private var totalPlannedScore: Int {
        summaries.reduce(0) { $0 + $1.plannedScore }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("本周计划工作量", systemImage: "calendar.badge.clock")
                .font(.headline.weight(.semibold))
                .foregroundStyle(FamilyDutyTheme.ink)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已分配任务")
                        .font(.caption)
                        .foregroundStyle(FamilyDutyTheme.secondaryInk)
                    Text("\(totalAssignedCount) 项")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(FamilyDutyTheme.fern)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(FamilyDutyTheme.fern.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("计划分值")
                        .font(.caption)
                        .foregroundStyle(FamilyDutyTheme.secondaryInk)
                    Text("\(totalPlannedScore) 分")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(FamilyDutyTheme.forest)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(FamilyDutyTheme.forest.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            Text("按当前周内已分配的固定任务和临时任务统计")
                .font(.caption)
                .foregroundStyle(FamilyDutyTheme.secondaryInk)

            if summaries.isEmpty {
                FamilyDutyEmptyState(
                    title: "暂无家庭成员",
                    message: "添加成员后，这里会显示本周计划工作量。",
                    symbolName: "person.2"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(summaries) { summary in
                        HStack(spacing: 12) {
                            Text(summary.memberName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(FamilyDutyTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Text("分配 \(summary.assignedCount) 项")
                                .font(.caption)
                                .foregroundStyle(FamilyDutyTheme.secondaryInk)
                            Text("\(summary.plannedScore) 分")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(FamilyDutyTheme.forest)
                        }
                        .frame(minHeight: FamilyDutyTheme.minimumHitSize)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(summary.memberName)，分配 \(summary.assignedCount) 项，计划 \(summary.plannedScore) 分")
                        .accessibilityIdentifier("planned-workload-\(summary.memberID.uuidString)")

                        if summary.id != summaries.last?.id {
                            Divider()
                        }
                    }
                }
                .accessibilityIdentifier("planned-workload-details")
            }
        }
        .padding(FamilyDutyTheme.cardPadding)
        .familyDutyCard()
        .accessibilityIdentifier("planned-workload-summary")
    }
}
