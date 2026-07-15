# 评分与工作量报表 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为固定值日和临时任务增加可配置得分，在当天任务面板展示家庭成员工作量图表，并提供可按日、周、月切换且可浏览历史日期的报表。

**Architecture:** 评分属于任务配置，但完成记录保存完成时的得分和工作日期快照。固定规则保存默认得分，生成任务时复制到 `ChoreTask`；临时任务直接设置得分；完成时复制到 `CompletionRecord`。纯统计逻辑集中在 `ScoreReportViewModel`，任务面板和报表页共用统计结果与 Swift Charts 视图，避免在 SwiftUI 页面中散落日期边界和汇总规则。

**Tech Stack:** Swift 5、SwiftUI、SwiftData、Foundation Calendar、Swift Charts、XCTest、XCUITest、XcodeGen。

## 需求口径与边界

- 每项工作有一个正整数得分，默认值为 1；UI 允许用户在创建/编辑工作时设置得分，包括示例中的 1、2、3。保存时拒绝小于 1 的值。
- 固定轮班的得分配置在 `ChoreRule`，生成出来的每个 `ChoreTask` 保存当时的得分快照。修改规则得分只影响重新生成的未开始任务，不回写已完成历史。
- 临时任务在创建时设置得分；调整单次任务时可以修改该次任务得分。
- “工作量”默认按已完成任务统计：完成数量、完成得分和成员占比。待处理/已取消任务不计入已完成得分，但当天面板可额外显示当天总任务与已完成总分。
- 报表归属日期使用任务完成时记录的 `workDate`，该值取任务当时的 `scheduledDate` 所在日；晚完成的任务仍归入原计划工作日。
- 周报使用 `Calendar.dateInterval(of: .weekOfYear, for:)`，月报使用 `.month`；所有边界函数都接收注入的 `Calendar` 和基准日期。
- 不引入远程同步、导出、家庭成员排名规则或自定义图表主题；先完成本地可视化和历史查询。

## Task 1: 扩展评分数据模型并保持历史快照

**Files:**

- Modify: `FamilyDuty/Models/ChoreRule.swift`
- Modify: `FamilyDuty/Models/ChoreTask.swift`
- Modify: `FamilyDuty/Models/CompletionRecord.swift`
- Modify: `FamilyDuty/Services/TaskGenerationService.swift`
- Modify: `FamilyDuty/Services/CompletionService.swift`
- Modify: `FamilyDutyTests/Services/TaskGenerationServiceTests.swift`
- Modify: `FamilyDutyTests/Services/CompletionServiceTests.swift`
- Modify: `FamilyDutyTests/Models/ModelPersistenceTests.swift`

**Specific operations:**

1. 在 `ChoreRule` 新增 `score: Int`，初始化默认值为 1，并扩展初始化器参数；保留旧调用点可用的默认参数，避免现有测试和种子数据全部改写。
2. 在 `ChoreTask` 新增 `score: Int`，初始化默认值为 1；该字段代表当前任务实例的得分，不通过计算属性动态读取规则得分。
3. 在 `CompletionRecord` 新增 `score: Int` 和 `workDate: Date`；初始化时从任务复制得分，并将任务计划日期归一化为工作日。完成记录继续保留 `completedByName`，用于成员删除后的历史展示。
4. 在 `TaskGenerationService.ensureTasks` 创建任务时传入 `rule.score`；既有任务不因重复生成而覆盖其分数。
5. 在 `CompletionService.complete` 创建记录时保存任务分数和工作日；保留现有保存失败时的任务状态及记录回滚行为。
6. 增加统一的 `ScoreValidationError.invalidScore` 和正整数验证入口，供规则保存、临时任务创建、单次调整共用；不把验证逻辑复制到多个视图。
7. 为规则生成、完成记录快照、临时任务默认得分、分数持久化和保存失败回滚补充单元测试。

## Task 2: 在所有任务编辑入口支持设置得分

**Files:**

- Modify: `FamilyDuty/Features/Rotation/RuleEditorView.swift`
- Modify: `FamilyDuty/Features/Rotation/RotationViewModel.swift`
- Modify: `FamilyDuty/Features/Tasks/TemporaryTaskEditorView.swift`
- Modify: `FamilyDuty/Features/Tasks/TemporaryTaskViewModel.swift`
- Modify: `FamilyDuty/Features/Tasks/TaskAdjustmentSheet.swift`
- Modify: `FamilyDutyTests/Features/RotationViewModelTests.swift`
- Modify: `FamilyDutyTests/Features/TemporaryTaskViewModelTests.swift`

**Specific operations:**

1. 在规则编辑表单增加“得分”输入，编辑既有规则时加载 `rule.score`，保存调用 `RotationViewModel.saveRule(..., score:)`。
2. 在 `RotationViewModel.saveRule` 中验证得分并写入新规则或既有规则；既有规则沿用当前策略删除并重新生成未来未调整 pending 任务，使新规则得分进入未来任务快照。
3. 在临时任务编辑表单增加同样的得分输入，扩展 `TemporaryTaskViewModel.createTask(..., score:)`，将分数写入临时 `ChoreTask`。
4. 在单次任务调整表单加载和编辑 `task.score`，扩展 `RotationViewModel.adjust(..., score:)`；取消任务时保留分数，恢复/改派任务时更新分数并继续使用现有 Deadline 校验。
5. 为空标题、无成员、无效 Deadline 与无效得分的错误提示增加覆盖；验证规则保存后生成任务继承规则分数，单次调整只修改当前任务。

## Task 3: 构建可测试的工作量统计 ViewModel

**Files:**

- Create: `FamilyDuty/Features/Reports/ScoreReportViewModel.swift`
- Create: `FamilyDuty/Features/Reports/ReportPeriod.swift`
- Create: `FamilyDutyTests/Features/ScoreReportViewModelTests.swift`

**Public design:**

- `ReportPeriod`: 表示 `.day(Date)`、`.week(Date)`、`.month(Date)`，负责生成标题、前后翻页日期和对应 `DateInterval`。
- `MemberWorkloadSummary`: 包含成员稳定 ID（可为空）、成员名称、完成数量、完成得分及占比所需总分。
- `WorkloadDataPoint`: 包含工作日、成员名称、成员 ID、得分和任务数量，供趋势图使用。
- `ScoreReportViewModel.summaries(for:period,members:records,calendar:)`：返回期间内每位成员的汇总，包含零分成员，按成员 `sortOrder` 或名称稳定排序。
- `ScoreReportViewModel.dailyDataPoints(for:period,records:calendar:)`：返回周/月期间按日和成员展开的数据点。
- `ScoreReportViewModel.latestRecords(from:)`：按任务 ID 去重，重复完成记录只取最新一条，防止历史数据重复累计。
- `ScoreReportViewModel.dateInterval(for:calendar:)`：统一计算日/周/月的开始与结束，不使用设备默认时区之外的隐式日期比较。

**Specific operations:**

1. 统计只使用 `CompletionRecord.score`、`CompletionRecord.workDate`、完成者关系及名称快照，不依赖当前任务分数，保证历史稳定。
2. 成员关系为空时使用 `completedByName` 生成“已删除成员”的汇总项；当前成员没有完成记录时仍返回零分项。
3. 日报输出当天每人的得分和完成数；周报/月报输出期间总计及按日数据点；总分为 0 时占比显示为 0，图表不发生除零。
4. 测试跨日、跨周、跨月边界，晚完成归入 `workDate`、成员删除快照、零分成员、重复完成记录和无记录空报表。

## Task 4: 在任务面板加入当天可视化报表

**Files:**

- Create: `FamilyDuty/Features/Reports/WorkloadChartView.swift`
- Create: `FamilyDuty/Features/Reports/WorkloadSummaryView.swift`
- Modify: `FamilyDuty/Features/TaskBoard/TaskBoardView.swift`
- Modify: `FamilyDuty/Features/TaskBoard/TaskBoardViewModel.swift`
- Modify: `FamilyDutyTests/Features/TaskBoardViewModelTests.swift`
- Modify: `FamilyDutyUITests/TaskBoardFlowUITests.swift`

**Specific operations:**

1. 新建共享工作量视图：使用 `Charts.BarMark` 展示成员得分，旁边显示“完成 X 项 · Y 分”；成员没有得分时也显示 0，保证家庭成员之间可比较。
2. 在任务面板新增成员查询，并在任务 Section 之前加入当天得分卡片；统计数据使用当天 `CompletionRecord.workDate`，不是当前时间或任务当前分数。
3. 顶部显示当天完成总分、完成数量和成员图表，保留现有 pending/completed/cancelled 列表与完成交互。
4. 增加“查看历史报表”导航入口，指向报表页；为图表、分数、历史入口提供稳定 accessibility identifier 和可读 label。
5. 更新 UI 测试种子：为当天完成任务设置不同分数，并验证面板能看到各成员分数、完成数量和“查看历史报表”入口；空任务时图表显示空状态而不崩溃。

## Task 5: 新增日报、周报、月报和历史浏览页面

**Files:**

- Create: `FamilyDuty/Features/Reports/ReportsView.swift`
- Create: `FamilyDuty/Features/Reports/ReportsViewModel.swift`
- Modify: `FamilyDuty/AppRootView.swift`
- Create: `FamilyDutyUITests/ReportsFlowUITests.swift`

**Specific operations:**

1. `ReportsView` 使用 `@Query` 读取 `FamilyMember` 和 `CompletionRecord`，提供“日报/周报/月报”分段选择器。
2. 提供历史日期选择器及前一天/前一周/前一月、后一天/后一周/后一月按钮；后续日期没有数据时仍显示零值报表，不能越界到当前日期限制用户查看历史。
3. 日报显示每成员柱状图、完成数量、得分和期间总分；周报/月报显示成员期间总分柱状图，以及按日展开的趋势图；图表下方提供可访问的文本明细，避免只依赖颜色和图形。
4. `ReportsViewModel` 只负责页面状态（当前 period、选择日期、前后翻页），统计计算委托给 `ScoreReportViewModel`，确保可用 XCTest 覆盖而无需渲染 SwiftUI。
5. 在 `MainTabView` 增加“报表”Tab，放在“任务面板”和“轮班”之间；保持现有 Tab 功能和 `primary-navigation` 标识不变。
6. UI 测试验证进入报表 Tab、切换日报/周报/月报、浏览历史日期、显示成员得分和零数据空状态；覆盖横向 iPad 下 Tab 和图表标题不截断。

## Task 6: 工程生成、迁移检查与完整验证

**Files:**

- Modify: `project.yml` only if XcodeGen source discovery needs an explicit new path
- Create or update: `docs/plans/2026-07-15-scoring-workload-reports.md`

**Verification:**

1. 运行 `xcodegen generate`，确认 Reports 目录下的新 Swift 文件进入应用和测试 target。
2. 运行 `xcodebuild build-for-testing -project FamilyDuty.xcodeproj -scheme FamilyDutyTests -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/family-duty-derived-data CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=''`，确认模型、Charts、单元测试可编译。
3. 运行 `xcodebuild test -project FamilyDuty.xcodeproj -scheme FamilyDutyTests -destination 'platform=iOS Simulator,name=iPad (10th generation)' -derivedDataPath /private/tmp/family-duty-derived-data CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=''`，执行完整 XCTest/XCUITest。
4. 检查 SwiftData 现有本地容器对新增非可选 Int/Date 字段的迁移行为；若当前模型无法对旧存储执行轻量迁移，则把默认值和容器迁移策略作为实现阻塞点报告，不静默删除用户数据。
5. 运行 `git diff --check`，检查无格式错误；人工检查日报、周报、月报在有数据、零数据、长成员名称和 iPad 横竖屏下均可读。

## Final acceptance criteria

1. 固定值日、临时任务、单次调整均能设置正整数得分，默认得分为 1。
2. 完成任务后，记录保存不可变的得分与工作日期快照；历史数据不因规则或任务后续编辑而变化。
3. 任务面板展示当天每个人的完成数量与得分可视化，并能进入历史报表。
4. 报表支持日报、周报、月报和历史日期浏览；每个成员含零值项，已删除成员仍能显示历史名称。
5. 统计边界、重复记录、保存失败、模型持久化和 UI 交互均有测试覆盖，构建与测试命令通过。
