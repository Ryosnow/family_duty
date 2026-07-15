# 家务历史中心实施记录

## 目标

为家庭值日增加独立的历史中心，支持查看全部完成记录、按日期/完成人/任务名称筛选、查看完成详情，并从历史记录创建新的类似临时任务。

## 实现方案

- 使用已有 `CompletionRecord`、`ChoreTask` 和 `FamilyMember`，不新增 SwiftData 模型字段，也不需要数据迁移。
- 历史列表通过 `HistoryViewModel` 做内存筛选，并复用报表的最新记录去重规则。
- 日期筛选基于 `CompletionRecord.workDate`，详情同时展示精确的 `completedAt`。
- 删除成员后，完成人筛选和详情使用 `completedByName` 历史快照。
- “重新创建类似任务”只复制标题和分值，生成新的临时任务，不复制旧日期、负责人、Deadline 或固定规则。

## 受影响文件

- `FamilyDuty/Features/History/HistoryViewModel.swift`
- `FamilyDuty/Features/History/HistoryView.swift`
- `FamilyDuty/Features/History/HistoryDetailView.swift`
- `FamilyDuty/Features/Tasks/TemporaryTaskDraft.swift`
- `FamilyDuty/Features/Tasks/TemporaryTaskEditorView.swift`
- `FamilyDuty/AppRootView.swift`
- `FamilyDutyTests/Features/HistoryViewModelTests.swift`
- `FamilyDutyUITests/HistoryFlowUITests.swift`
- `README.md`

## 验证范围

- ViewModel 单元测试覆盖日期、成员、任务名称、删除成员快照、重复记录和重新创建草稿。
- UI 测试覆盖历史 Tab、完整记录列表、搜索、详情和回填临时任务表单。
- 工程验证包括 XcodeGen、完整测试 Scheme、iPad 横竖屏检查和 `git diff --check`。
