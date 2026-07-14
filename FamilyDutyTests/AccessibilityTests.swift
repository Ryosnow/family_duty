import XCTest
import UserNotifications
@testable import FamilyDuty

final class AccessibilityTests: XCTestCase {
    func testTaskAccessibilityLabelIncludesTitleAssigneeAndSource() {
        let member = FamilyMember(name: "小明", sortOrder: 0)
        let task = ChoreTask(title: "收快递", scheduledDate: .now, assignee: member, isTemporary: true)

        XCTAssertEqual(
            DashboardViewModel.accessibilityLabel(for: task),
            "收快递，负责人小明，临时任务"
        )
    }

    func testDeniedNotificationPermissionHasRecoveryMessage() {
        XCTAssertEqual(
            NotificationPermissionPresentation.message(for: .denied),
            "系统通知权限已关闭，任务管理仍可正常使用。"
        )
        XCTAssertNil(NotificationPermissionPresentation.message(for: .authorized))
    }
}
