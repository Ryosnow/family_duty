import SwiftUI

struct FamilyDutyMemberColorOption: Identifiable {
    let name: String
    let title: String
    let color: Color

    var id: String { name }
}

enum FamilyDutyMemberColor {
    static let options = [
        FamilyDutyMemberColorOption(name: "blue", title: "海蓝", color: Color(red: 0.18, green: 0.45, blue: 0.78)),
        FamilyDutyMemberColorOption(name: "purple", title: "葡萄紫", color: Color(red: 0.48, green: 0.34, blue: 0.72)),
        FamilyDutyMemberColorOption(name: "orange", title: "暖橙", color: Color(red: 0.85, green: 0.43, blue: 0.16)),
        FamilyDutyMemberColorOption(name: "green", title: "青草绿", color: Color(red: 0.18, green: 0.53, blue: 0.34)),
        FamilyDutyMemberColorOption(name: "pink", title: "樱花粉", color: Color(red: 0.76, green: 0.30, blue: 0.48)),
        FamilyDutyMemberColorOption(name: "teal", title: "湖水青", color: Color(red: 0.10, green: 0.52, blue: 0.55))
    ]

    static func color(for name: String) -> Color {
        options.first { $0.name == name }?.color ?? options[0].color
    }

    static func colorName(for name: String) -> String {
        options.first { $0.name == name }?.name ?? options[0].name
    }

    static func defaultName(forSortOrder sortOrder: Int) -> String {
        options[sortOrder.quotientAndRemainder(dividingBy: options.count).remainder].name
    }
}
