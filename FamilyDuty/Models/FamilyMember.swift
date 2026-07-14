import Foundation
import SwiftData

@Model
final class FamilyMember {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorName: String
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, colorName: String = "blue", sortOrder: Int) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.sortOrder = sortOrder
    }
}
