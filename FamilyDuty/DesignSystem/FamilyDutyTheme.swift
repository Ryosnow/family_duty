import SwiftUI

enum FamilyDutyTheme {
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let cardBackground = Color(uiColor: .systemBackground)
    static let ink = Color(uiColor: .label)
    static let secondaryInk = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)

    static let forest = Color(red: 0.12, green: 0.30, blue: 0.23)
    static let fern = Color(red: 0.18, green: 0.49, blue: 0.36)
    static let sunflower = Color(red: 0.91, green: 0.61, blue: 0.16)
    static let coral = Color(red: 0.78, green: 0.28, blue: 0.24)
    static let mint = Color(red: 0.82, green: 0.92, blue: 0.85)
    static let lavender = Color(red: 0.74, green: 0.75, blue: 0.93)

    static let pagePadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let cardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 20
    static let compactCornerRadius: CGFloat = 12
    static let minimumHitSize: CGFloat = 44
    static let iconSize: CGFloat = 20
}

extension View {
    func familyDutyCard(cornerRadius: CGFloat = FamilyDutyTheme.cardCornerRadius) -> some View {
        background(
            FamilyDutyTheme.cardBackground,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(FamilyDutyTheme.separator.opacity(0.35), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}
