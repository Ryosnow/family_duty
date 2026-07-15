import SwiftUI

struct FamilyDutyIconBadge: View {
    let symbolName: String
    let tint: Color
    var accessibilityLabel: String?
    var size: CGFloat = FamilyDutyTheme.minimumHitSize

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: FamilyDutyTheme.iconSize, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: Circle())
            .accessibilityLabel(accessibilityLabel ?? symbolName)
    }
}

struct FamilyDutySectionHeader: View {
    let title: String
    let symbolName: String
    var tint: Color = FamilyDutyTheme.forest
    var count: Int?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(FamilyDutyTheme.ink)
            if let count {
                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 24)
                    .background(tint.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct FamilyDutyStatusPill: View {
    let title: String
    let symbolName: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(tint.opacity(0.13), in: Capsule())
            .accessibilityElement(children: .combine)
    }
}

struct FamilyDutyProgressRing: View {
    let progress: Double
    let completed: Int
    let total: Int

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 9)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(FamilyDutyTheme.sunflower, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(completed)/\(total)")
                    .font(.title3.weight(.bold).monospacedDigit())
                Text("完成")
                    .font(.caption2.weight(.medium))
                    .opacity(0.82)
            }
            .foregroundStyle(.white)
        }
        .frame(width: 96, height: 96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日完成进度")
        .accessibilityValue("已完成 \(completed) 项，共 \(total) 项")
    }
}

struct FamilyDutyMemberChip: View {
    let name: String
    var tint: Color = FamilyDutyTheme.fern

    var body: some View {
        HStack(spacing: 8) {
            Text(String(name.prefix(1)))
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: Circle())
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(FamilyDutyTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: FamilyDutyTheme.minimumHitSize, alignment: .leading)
    }
}

struct FamilyDutyEmptyState: View {
    let title: String
    let message: String
    let symbolName: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            FamilyDutyIconBadge(symbolName: symbolName, tint: FamilyDutyTheme.fern, size: 56)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(FamilyDutyTheme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(FamilyDutyTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(FamilyDutyTheme.forest)
                    .frame(minHeight: FamilyDutyTheme.minimumHitSize)
            }
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, FamilyDutyTheme.cardPadding)
        .familyDutyCard()
    }
}

struct FamilyDutyTaskCard: View {
    let title: String
    let assignee: String
    let metadata: String
    let deadline: String?
    let symbolName: String
    var accent: Color = FamilyDutyTheme.fern
    var memberTint: Color?
    var statusTitle: String?
    var statusSymbolName: String?
    var statusTint: Color = FamilyDutyTheme.fern
    var isOverdue = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            FamilyDutyIconBadge(
                symbolName: symbolName,
                tint: isOverdue ? FamilyDutyTheme.coral : accent,
                accessibilityLabel: title
            )
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(FamilyDutyTheme.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if let statusTitle, let statusSymbolName {
                        FamilyDutyStatusPill(title: statusTitle, symbolName: statusSymbolName, tint: statusTint)
                    }
                }
                FamilyDutyMemberChip(name: assignee, tint: memberTint ?? accent)
                Text(metadata)
                    .font(.subheadline)
                    .foregroundStyle(FamilyDutyTheme.secondaryInk)
                if let deadline {
                    Label(deadline, systemImage: isOverdue ? "clock.badge.exclamationmark" : "clock")
                        .font(.caption)
                        .foregroundStyle(isOverdue ? FamilyDutyTheme.coral : FamilyDutyTheme.secondaryInk)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FamilyDutyTheme.cardPadding)
        .familyDutyCard()
        .contentShape(RoundedRectangle(cornerRadius: FamilyDutyTheme.cardCornerRadius, style: .continuous))
    }
}
