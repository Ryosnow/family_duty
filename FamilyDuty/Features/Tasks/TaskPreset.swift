import Foundation

struct TaskPreset: Identifiable, Hashable {
    let title: String
    let emoji: String
    let symbolName: String

    init(title: String, emoji: String, symbolName: String = "checkmark.circle") {
        self.title = title
        self.emoji = emoji
        self.symbolName = symbolName
    }

    var id: String { title }
}
