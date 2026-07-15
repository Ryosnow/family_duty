# 任务面板功能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 新增独立“任务面板”Tab，展示当天所有任务，包括待处理、已完成和已取消任务，并显示对应状态与完成信息。

**Architecture:** 任务面板直接查询现有 `ChoreTask` 和 `CompletionRecord`，不新增 SwiftData 模型。`TaskBoardViewModel` 负责按注入的 Calendar 判断任务是否属于当天、按状态分组及关联最新完成记录；`TaskBoardView` 负责展示和交互。将当前 Dashboard 私有的完成确认页抽成共享 `CompletionSheet`，让首页和任务面板共用现有完成服务、领取流程和单次调整流程。

**Tech Stack:** Swift 5、SwiftUI、SwiftData、Foundation Calendar、XCTest、XCUITest、XcodeGen。

## 需求边界

- 任务面板默认展示系统当前日；本版不增加日期切换控件，避免扩展为历史任务浏览器。
- 以 `scheduledDate` 所在日判断“当天”，不以 Deadline 或完成时间判断归属。
- 显示 `pending`、`completed`、`cancelled` 三种状态；已完成任务从任务面板保留，但不再打开完成确认；已取消任务只读展示。
- 待处理任务仍可领取、完成和调整；面板上的操作与首页保持一致。
- 已完成任务显示最新 `CompletionRecord` 的完成者快照和完成时间；如果记录缺失，仍显示任务状态，并显示“暂无完成记录”作为降级文案。
- 任务的逾期红点只对未完成任务生效；完成和取消状态不显示逾期。
- 不修改轮班生成、任务持久化字段、Deadline 规则或首页现有分组逻辑。

## Task 1: 设计并实现任务面板 ViewModel

**Files:**

- Create: `FamilyDuty/Features/TaskBoard/TaskBoardViewModel.swift`
- Create: `FamilyDutyTests/Features/TaskBoardViewModelTests.swift`

### Step 1: 编写失败测试

测试 ViewModel 的以下行为：

1. 只返回 `scheduledDate` 与注入 `now` 同一天的任务。
2. 同一天任务包含 pending、completed 和 cancelled，不因状态被过滤。
3. 前一天、后一天任务不进入当天结果。
4. 任务按 pending、completed、cancelled 分组时数量正确。
5. 待处理任务按 Deadline/计划日期排序；已完成任务按最新完成时间倒序；已取消任务按计划日期排序。
6. 同一任务存在多条完成记录时只关联最新记录。
7. completed 任务没有完成记录时返回空记录，供页面显示降级文案。

ViewModel 的公开能力包括：当天任务筛选、状态分组、待处理/已完成/已取消排序，以及按任务查找最新完成记录。所有日期函数接收 Calendar 和 now，测试不依赖设备当前日期。

### Step 2: 运行测试确认失败

运行：

`xcodebuild build-for-testing -project FamilyDuty.xcodeproj -scheme FamilyDutyTests -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/family-duty-derived-data CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=''`

预期：因 `TaskBoardViewModel` 尚不存在而失败。

### Step 3: 实现最小 ViewModel

在 `TaskBoardViewModel` 中实现当天筛选、三种状态分组、确定性排序和最新完成记录关联。排序比较使用有效 Deadline 服务；completed/cancelled 不因逾期而改变状态或排序。

### Step 4: 运行测试确认通过

运行同一 build-for-testing 命令，预期 FamilyDutyTests target 编译通过。若当前环境存在可用 iPad Simulator，再运行 TaskBoardViewModelTests；否则保留 generic 编译和后续完整测试结果。

## Task 2: 抽取共享完成流程并创建任务面板页面

**Files:**

- Create: `FamilyDuty/Features/Tasks/CompletionSheet.swift`
- Create: `FamilyDuty/Features/TaskBoard/TaskBoardView.swift`
- Modify: `FamilyDuty/Features/Dashboard/DashboardView.swift`
- Modify: `FamilyDuty/AppRootView.swift`

### Step 1: 抽取共享完成确认页

将 Dashboard 中的私有 `CompletionSheet` 移至 `Features/Tasks/CompletionSheet.swift`，保持标题、成员选择、完成服务调用、错误提示和 accessibility 行为不变。Dashboard 改为引用共享组件，先运行现有 Dashboard UI 测试确认无回归。

### Step 2: 实现任务面板页面

使用 `@Query` 读取全部 `ChoreTask` 和按时间倒序的 `CompletionRecord`。页面标题为“任务面板”，顶部显示当天任务总数；下方显示“待处理”“已完成”“已取消”三个 Section。每条任务展示标题、负责人、来源、计划日期和有效 Deadline。

待处理任务：沿用首页点击行为，未领取打开 `ClaimTaskSheet`，已领取打开共享 `CompletionSheet`；滑动操作打开 `TaskAdjustmentSheet`。

已完成任务：显示绿色“已完成”状态、完成者和完成时间，只读展示。已取消任务：显示灰色“已取消”状态和调整说明，只读展示。逾期的待处理任务显示红点和红色 Deadline；完成/取消任务不显示红点。

没有当天任务时显示“今天没有任务”，并保留可访问的空状态文案。

### Step 3: 增加导航入口

在 `MainTabView` 增加第四个 Tab，标签为“任务面板”，使用 checklist 类系统图标，并增加稳定的 `task-board-tab` accessibility identifier。保持首页、轮班、设置 Tab 的顺序和现有入口不变。

## Task 3: 增加测试种子、UI 测试和工程验证

**Files:**

- Create: `FamilyDutyUITests/TaskBoardFlowUITests.swift`
- Modify: `FamilyDuty/AppRootView.swift`
- Modify: `project.yml` only if target source discovery requires it
- Modify: `FamilyDutyTests/AccessibilityTests.swift` only if new labels need focused assertions

### Step 1: 增加 UI 测试种子

增加 `-seedTaskBoard` 启动参数：创建一个家庭成员、一个当天待处理任务、一个当天已完成任务及其 `CompletionRecord`、一个当天已取消任务。种子数据仅用于 UI 测试，不改变正常启动行为。

### Step 2: 编写 UI 测试

新增测试验证：

1. 启动后可以进入“任务面板”Tab。
2. 当天待处理、已完成和已取消任务同时可见。
3. 已完成任务显示完成者和完成时间文案。
4. 点击待处理任务仍能打开“确认完成”，完成后任务面板状态更新。
5. 其他日期任务不显示在任务面板。

### Step 3: 重新生成工程并执行验证

运行 `xcodegen generate`，确认新 Swift 文件加入对应 target。

运行应用构建：

`xcodebuild -project FamilyDuty.xcodeproj -scheme FamilyDuty -sdk iphonesimulator build -derivedDataPath /private/tmp/family-duty-derived-data CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=''`

运行完整测试：

`xcodebuild test -project FamilyDuty.xcodeproj -scheme FamilyDutyTests -destination 'platform=iOS Simulator,name=iPad (10th generation)' -derivedDataPath /private/tmp/family-duty-derived-data CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=''`

预期：现有单元/UI 测试与新增任务面板测试全部通过；同时检查横竖屏下四个 Tab 和当天三种任务 Section 无布局截断。

## Final Verification Steps

1. 任务面板只显示当天 `scheduledDate` 任务。
2. pending、completed、cancelled 三种任务均可见且状态清晰。
3. 已完成任务显示最新完成记录，缺失记录时有降级文案。
4. pending 任务仍可领取、完成和调整；完成后状态从待处理移动到已完成。
5. Deadline 红点规则与首页一致。
6. 应用构建、全量 XCTest、UI 测试和 `git diff --check` 全部通过。
