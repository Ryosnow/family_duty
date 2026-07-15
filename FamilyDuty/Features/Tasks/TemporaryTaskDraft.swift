import Foundation

struct TemporaryTaskDraft: Identifiable, Equatable {
    let id: UUID
    let title: String
    let score: Int

    init(id: UUID = UUID(), title: String, score: Int) {
        self.id = id
        self.title = title
        self.score = score
    }
}
