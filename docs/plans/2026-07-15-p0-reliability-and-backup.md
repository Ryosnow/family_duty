# P0 Reliability and Backup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修复固定任务长期生成、完成撤销、本地备份恢复和通知跨天过期四项 P0 问题，保持当前单设备离线产品范围不变。

**Architecture:** 在 App 根层增加可重复执行的前台刷新协调入口，统一触发固定任务滚动补齐和通知重排；任务完成撤销与备份恢复分别封装在可测试的 MainActor 服务中。备份使用带版本号的 Codable DTO 保存成员、规则、任务和完成记录及其关系 ID，不引入云同步或第三方依赖。

**Tech Stack:** SwiftUI、SwiftData、UserNotifications、UniformTypeIdentifiers、XCTest/XCUITest、iPadOS 17。

### Task 1: 自动滚动生成未来固定任务

**Files:**
- Create: `FamilyDuty/Services/TaskGenerationCoordinator.swift`
- Modify: `FamilyDuty/AppRootView.swift`
- Modify: `FamilyDuty/FamilyDutyApp.swift` only if foreground refresh ownership needs to move to the app root
- Test: `FamilyDutyTests/Services/TaskGenerationServiceTests.swift`
- Test: `FamilyDutyTests/Services/TaskGenerationCoordinatorTests.swift`

**Operations:**

1. 先添加失败测试，验证启用规则会从当前日期补齐至少未来 8 周任务，重复触发不会创建重复任务，已完成/手动调整任务不会被覆盖，停用规则不会生成任务。
2. 添加协调服务，接收 ModelContext、Calendar、当前时间和生成周期；内部调用现有 `TaskGenerationService`，不复制轮班算法。
3. 在应用启动和回到前台时触发协调服务；确保 UI 测试内存容器也能正常运行。
4. 使用幂等生成和单次保存，生成失败时向根层提供可展示的错误，不影响已有任务查看。
5. 更新 README，说明应用会自动维护未来任务窗口。

### Task 2: 撤销完成与重新完成

**Files:**
- Modify: `FamilyDuty/Services/CompletionService.swift`
- Modify: `FamilyDuty/Features/TaskBoard/TaskBoardView.swift`
- Create: `FamilyDuty/Features/Tasks/CompletionCorrectionSheet.swift` only if the existing completion sheet cannot表达撤销流程 cleanly
- Test: `FamilyDutyTests/Services/CompletionServiceTests.swift`
- Test: `FamilyDutyUITests/TaskBoardFlowUITests.swift`

**Operations:**

1. 先添加失败测试，验证已完成任务可以找到最新完成记录并原子恢复为待处理，同时删除对应完成记录；不存在记录、任务不是已完成状态、保存失败时返回明确错误并恢复原状。
2. 在 `CompletionService` 增加撤销完成 API，按任务选择最新记录，避免旧重复记录被误删。
3. 在任务面板已完成任务上提供“撤销完成”确认操作；撤销后任务回到待处理区，并可按现有流程重新选择实际完成人。
4. 保持报表去重和历史快照语义不变；不增加第二种完成记录状态。
5. 补充 UI 测试，验证完成、撤销、再次完成的完整流程。

### Task 3: 本地备份、导出和恢复

**Files:**
- Create: `FamilyDuty/Services/LocalBackupService.swift`
- Create: `FamilyDuty/Services/FamilyDutyBackupDocument.swift`
- Create: `FamilyDuty/Features/Settings/DataManagementView.swift`
- Modify: `FamilyDuty/Features/Settings/SettingsView.swift`
- Test: `FamilyDutyTests/Services/LocalBackupServiceTests.swift`
- Test: `FamilyDutyUITests/AccessibilityUITests.swift` or a focused settings UI test

**Operations:**

1. 先添加失败测试，覆盖成员、规则、任务、完成记录的完整往返导出/恢复，关系 ID、参与者顺序、任务状态、得分、截止日期和完成者姓名快照均保持一致。
2. 定义版本化备份 DTO；导入前校验版本、重复 ID、缺失关系、非法状态、非法得分和非法截止日期。
3. 实现导出为本地 JSON 文件，使用 SwiftUI `fileExporter`，不上传网络。
4. 实现恢复流程，默认提供明确的“替换当前本地数据”确认；在单次事务中删除并重建数据，失败时回滚且不破坏现有数据。
5. 在设置页增加“数据管理”入口，并展示最近一次导出/恢复结果和错误信息。
6. 更新 README，说明备份文件是离线手动备份，不代表云同步。

### Task 4: 修正通知跨天过期

**Files:**
- Modify: `FamilyDuty/Services/NotificationScheduler.swift`
- Modify: `FamilyDuty/Services/NotificationAuthorizationService.swift` if the client protocol needs one-shot trigger support
- Modify: `FamilyDuty/Services/NotificationScheduleRefreshModifier.swift`
- Modify: `FamilyDuty/Features/Settings/NotificationSettingsView.swift` only for visible copy or refresh behavior
- Test: `FamilyDutyTests/Services/NotificationSchedulerTests.swift`

**Operations:**

1. 先添加失败测试，验证不同日期的通知正文按各自日期生成，通知请求为一次性触发，刷新时会清理旧的托管请求而不影响其他应用请求。
2. 将通知中心客户端扩展为支持 `repeats` 或明确的一次性请求；兼容清理当前版本的旧固定 ID。
3. 为未来 7 天分别生成每日汇总；逾期汇总按每个日期计算当日已逾期的待处理任务。
4. 在应用启动、回到前台、任务变化和提醒设置变化时重排请求；保持通知权限拒绝不阻断任务管理。
5. 保持现有每日汇总时间和逾期提醒时间设置不变。

### Task 5: 集成验证与文档

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md` only if the implemented architecture or testing commands change

**Verification:**

1. 按 TDD 顺序逐项执行失败测试、最小实现、专项测试和重构后专项测试。
2. 运行完整 `FamilyDutyTests` Scheme，覆盖单元测试和 UI 测试。
3. 运行无代码签名构建，确认 SwiftData 模型、文件导入导出和通知 API 在 iPadOS 17 目标下编译通过。
4. 检查横屏、竖屏、浅色、深色和最大动态字体下的任务面板、设置和备份入口。
5. 检查 `git diff`，确认没有生成 DerivedData、个人数据或凭据。
