import Foundation

enum TaskPresetCatalog {
    static let fallbackEmoji = "📝"

    static let all: [TaskPreset] = [
        TaskPreset(title: "扫地", emoji: "🧹"),
        TaskPreset(title: "拖地", emoji: "🧽"),
        TaskPreset(title: "擦桌子", emoji: "🧼"),
        TaskPreset(title: "洗碗", emoji: "🍽️"),
        TaskPreset(title: "倒垃圾", emoji: "🗑️"),
        TaskPreset(title: "整理房间", emoji: "🧺"),
        TaskPreset(title: "洗衣服", emoji: "👕"),
        TaskPreset(title: "晾衣服", emoji: "🧦"),
        TaskPreset(title: "擦窗户", emoji: "🪟"),
        TaskPreset(title: "清洁卫生间", emoji: "🚽"),
        TaskPreset(title: "整理冰箱", emoji: "🧊"),
        TaskPreset(title: "浇花", emoji: "🪴"),
        TaskPreset(title: "喂宠物", emoji: "🐾"),
        TaskPreset(title: "整理书桌", emoji: "📚"),
        TaskPreset(title: "更换床单", emoji: "🛏️"),
        TaskPreset(title: "准备晚餐", emoji: "🍳")
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

    private static func normalize(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func leadingKnownEmoji(in title: String) -> String? {
        all.map(\.emoji).first { title.hasPrefix($0) }
    }
}
