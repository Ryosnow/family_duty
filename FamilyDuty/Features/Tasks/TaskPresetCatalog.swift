import Foundation

enum TaskPresetCatalog {
    static let fallbackEmoji = "📝"

    static let all: [TaskPreset] = [
        TaskPreset(title: "扫地", emoji: "🧹", symbolName: "wand.and.stars"),
        TaskPreset(title: "拖地", emoji: "🧽", symbolName: "drop"),
        TaskPreset(title: "擦桌子", emoji: "🧼", symbolName: "rectangle.and.pencil.and.ellipsis"),
        TaskPreset(title: "洗碗", emoji: "🍽️", symbolName: "fork.knife"),
        TaskPreset(title: "倒垃圾", emoji: "🗑️", symbolName: "trash"),
        TaskPreset(title: "整理房间", emoji: "🧺", symbolName: "square.grid.2x2"),
        TaskPreset(title: "洗衣服", emoji: "👕", symbolName: "tshirt"),
        TaskPreset(title: "晾衣服", emoji: "🧦", symbolName: "sun.max"),
        TaskPreset(title: "擦窗户", emoji: "🪟", symbolName: "rectangle.portrait"),
        TaskPreset(title: "清洁卫生间", emoji: "🚽", symbolName: "drop.circle"),
        TaskPreset(title: "整理冰箱", emoji: "🧊", symbolName: "refrigerator"),
        TaskPreset(title: "浇花", emoji: "🪴", symbolName: "leaf"),
        TaskPreset(title: "喂宠物", emoji: "🐾", symbolName: "pawprint"),
        TaskPreset(title: "整理书桌", emoji: "📚", symbolName: "books.vertical"),
        TaskPreset(title: "更换床单", emoji: "🛏️", symbolName: "bed.double"),
        TaskPreset(title: "准备晚餐", emoji: "🍳", symbolName: "fork.knife.circle")
    ]

    static func preset(named title: String) -> TaskPreset? {
        let normalizedTitle = normalize(title)
        return all.first { $0.title == normalizedTitle }
    }

    static func emoji(for title: String) -> String {
        let normalizedTitle = normalize(title)
        if let leadingEmoji = leadingKnownEmoji(in: normalizedTitle) {
            return leadingEmoji
        }
        return preset(named: normalizedTitle)?.emoji ?? fallbackEmoji
    }

    static func displayTitle(for title: String) -> String {
        let normalizedTitle = normalize(title)
        guard !normalizedTitle.isEmpty else { return normalizedTitle }
        guard leadingKnownEmoji(in: normalizedTitle) == nil else { return normalizedTitle }
        return "\(emoji(for: normalizedTitle)) \(normalizedTitle)"
    }

    static func titleWithoutKnownEmoji(for title: String) -> String {
        let normalizedTitle = normalize(title)
        guard let leadingEmoji = leadingKnownEmoji(in: normalizedTitle) else { return normalizedTitle }
        return String(normalizedTitle.dropFirst(leadingEmoji.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func symbolName(for title: String) -> String {
        let normalizedTitle = titleWithoutKnownEmoji(for: title)
        return preset(named: normalizedTitle)?.symbolName ?? "checkmark.circle"
    }

    private static func normalize(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func leadingKnownEmoji(in title: String) -> String? {
        all.map(\.emoji).first { title.hasPrefix($0) }
    }
}
