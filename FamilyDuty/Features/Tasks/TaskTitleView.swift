import SwiftUI

struct TaskTitleView: View {
    let title: String

    private var titleWithoutKnownEmoji: String {
        TaskPresetCatalog.titleWithoutKnownEmoji(for: title)
    }

    private var symbolName: String {
        TaskPresetCatalog.symbolName(for: title)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FamilyDutyTheme.fern)
                .frame(width: 24, height: 24)
                .background(FamilyDutyTheme.mint.opacity(0.7), in: Circle())
                .accessibilityHidden(true)
            Text(titleWithoutKnownEmoji)
        }
    }
}
