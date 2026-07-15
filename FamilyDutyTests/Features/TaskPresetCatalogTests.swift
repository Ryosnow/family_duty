import XCTest
@testable import FamilyDuty

final class TaskPresetCatalogTests: XCTestCase {
    func testCatalogContainsCommonPresetTitlesAndEmojis() {
        XCTAssertEqual(TaskPresetCatalog.preset(named: "扫地")?.emoji, "🧹")
        XCTAssertEqual(TaskPresetCatalog.preset(named: "拖地")?.emoji, "🧽")
        XCTAssertEqual(TaskPresetCatalog.preset(named: "擦桌子")?.emoji, "🧼")
    }

    func testPresetLookupTrimsWhitespace() {
        XCTAssertEqual(TaskPresetCatalog.preset(named: "  扫地  ")?.title, "扫地")
    }

    func testUnknownTaskUsesNoteEmoji() {
        XCTAssertEqual(TaskPresetCatalog.emoji(for: "整理阳台"), "📝")
        XCTAssertEqual(TaskPresetCatalog.displayTitle(for: "整理阳台"), "📝 整理阳台")
    }

    func testDisplayTitleDoesNotDuplicateKnownEmoji() {
        XCTAssertEqual(TaskPresetCatalog.displayTitle(for: "🧹 扫地"), "🧹 扫地")
    }

    func testPresetTitlesAreUnique() {
        let titles = TaskPresetCatalog.all.map(\.title)

        XCTAssertEqual(Set(titles).count, titles.count)
    }
}
