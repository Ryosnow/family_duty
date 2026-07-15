import Foundation

struct TaskPreset: Identifiable, Hashable {
    let title: String
    let emoji: String

    var id: String { title }
}
