import SwiftUI

struct TaskTitleView: View {
    let title: String

    private var titleWithoutKnownEmoji: String {
        let emoji = TaskPresetCatalog.emoji(for: title)
        guard title.hasPrefix(emoji) else { return title }
        return String(title.dropFirst(emoji.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(TaskPresetCatalog.emoji(for: title))
                .accessibilityHidden(true)
            Text(titleWithoutKnownEmoji)
        }
    }
}
