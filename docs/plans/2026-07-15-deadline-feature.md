# Deadline 功能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为每个任务增加可选的日期级 Deadline；未设置时默认截止任务计划日当天，逾期的未完成任务在首页单独展示并使用红色视觉标识。

**Architecture:** Deadline 存储在 `ChoreTask` 实例上，而不是 `ChoreRule` 上，因此可以单独调整某一次固定任务，也不会改变后续轮班规则。使用一个独立的 deadline 服务统一“未设置时取计划日”“只对未完成任务判定逾期”“按日比较”的规则；首页 ViewModel 复用该服务，编辑 ViewModel 负责校验和持久化。SwiftData 通过新增可选字段保持已有数据兼容，历史任务的 `nil` Deadline 自动按计划日计算。

**Tech Stack:** Swift 5、SwiftUI、SwiftData、Foundation Calendar、XCTest、XCUITest。

## 需求边界与行为约定

- Deadline 为日期，不增加时分选择；这是为了与当前任务的日期粒度保持一致。
- `ChoreTask.deadline` 使用可选日期保存“是否明确设置过 Deadline”。`nil` 不代表没有截止时间，而代表有效截止日为 `scheduledDate` 当天。
- 逾期判定只针对 `pending` 任务：当前日已经晚于有效截止日时为逾期；`completed` 和 `cancelled` 永远不显示逾期状态。
- Deadline 不能早于任务的计划日期。保存时返回明确的校验错误，不静默修改用户输入。
- 临时任务创建页和固定任务单次调整页都可以设置/取消 Deadline。固定轮班规则本身不增加默认 Deadline 配置；自动生成的固定任务默认使用当天截止，具体某一次任务通过“调整”设置。
- 首页增加“已逾期”分组，集中展示所有逾期未完成任务，避免计划日期已经过去的任务从“今天/本周稍后/临时任务”列表中消失。逾期任务行显示红点与红色截止日期，并在无障碍标签中包含“已逾期”。

## Task 1: 增加任务 Deadline 数据模型与统一业务规则

**Files:**

- Modify: `FamilyDuty/Models/ChoreTask.swift`
- Create: `FamilyDuty/Services/TaskDeadlineService.swift`
- Modify: `FamilyDutyTests/Models/ModelPersistenceTests.swift`
- Create: `FamilyDutyTests/Services/TaskDeadlineServiceTests.swift`

### Step 1: 编写失败测试

增加模型持久化测试，验证任务可以保存 `nil` Deadline 和明确设置的 Deadline，并在重新读取后保持值。

增加 deadline 服务测试，覆盖以下行为：

1. `nil` Deadline 的有效截止日为 `scheduledDate` 所在日。
2. 当前日等于有效截止日时不逾期，当前日为下一日时逾期。
3. 已完成和已取消任务即使日期已过也不逾期。
4. 使用注入的 Calendar 和时区进行日界线计算。
5. Deadline 早于计划日期时返回专用校验错误。

运行指定测试，确认新 API 尚不存在或测试失败。

### Step 2: 实现最小模型与服务

在 `ChoreTask` 增加可选 `deadline` 属性及初始化参数，保持所有现有调用点可编译；自动生成任务不传 Deadline，从而继续使用当天默认行为。

在 `TaskDeadlineService` 集中实现：有效截止日计算、日期归一化、逾期判断和 Deadline 校验。服务的公开函数必须接收 Calendar/当前时间参数，测试不得依赖设备当前时区或真实时间。

由于新字段为可选值，现有 SwiftData 数据在迁移后仍可读取；不新增用户数据迁移页面。`ModelContainerFactory` 仅在编译或持久化验证发现需要时调整模型注册。

### Step 3: 运行测试并确认通过

运行 `xcodebuild test -project FamilyDuty.xcodeproj -scheme FamilyDutyTests -destination 'platform=iOS Simulator,name=iPad (10th generation)' -only-testing:FamilyDutyTests/ModelPersistenceTests -only-testing:FamilyDutyTests/TaskDeadlineServiceTests`。

预期：新增持久化和 deadline 规则测试全部通过。

## Task 2: 接入临时任务创建和固定任务单次调整

**Files:**

- Modify: `FamilyDuty/Features/Tasks/TemporaryTaskViewModel.swift`
- Modify: `FamilyDuty/Features/Tasks/TemporaryTaskEditorView.swift`
- Modify: `FamilyDuty/Features/Rotation/RotationViewModel.swift`
- Modify: `FamilyDuty/Features/Tasks/TaskAdjustmentSheet.swift`
- Modify: `FamilyDutyTests/Features/TemporaryTaskViewModelTests.swift`
- Modify: `FamilyDutyTests/Features/RotationViewModelTests.swift`

### Step 1: 编写失败测试

在临时任务 ViewModel 测试中增加：

1. 创建任务时保存明确 Deadline。
2. 不设置 Deadline 时保持 `nil`，但有效截止日仍为计划日。
3. 拒绝早于计划日期的 Deadline。

在轮班 ViewModel 测试中增加：

1. 调整固定任务时可设置 Deadline。
2. 调整任务日期时可以同时更新 Deadline。
3. 清除 Deadline 后恢复当天默认规则。
4. 拒绝无效的 Deadline，且任务原有字段不被部分修改。

运行相关测试，确认新参数和校验尚未实现。

### Step 2: 实现 ViewModel 参数与持久化

扩展 `TemporaryTaskViewModel.createTask`，接收可选 Deadline，在创建前使用统一服务校验并保存归一化日期。

扩展 `RotationViewModel.adjust`，接收可选 Deadline，先校验全部变更，再一次性更新负责人、计划日期、状态说明和 Deadline，最后保存。取消任务时保留当前 Deadline，不让取消流程意外清空截止设置。

### Step 3: 实现两个编辑页面的控件

在 `TemporaryTaskEditorView` 和 `TaskAdjustmentSheet` 增加“设置 Deadline”开关：关闭时传入 `nil`；打开时显示日期选择器，初始值为任务计划日期或已有 Deadline。

当用户修改计划日期时，Deadline 日期选择器不被静默覆盖；如果已有 Deadline 因此早于新的计划日期，保存时显示校验错误，用户可以回到表单修正。保存按钮继续遵守现有标题/负责人等校验规则。

### Step 4: 运行相关测试

运行 `xcodebuild test -project FamilyDuty.xcodeproj -scheme FamilyDutyTests -destination 'platform=iOS Simulator,name=iPad (10th generation)' -only-testing:FamilyDutyTests/TemporaryTaskViewModelTests -only-testing:FamilyDutyTests/RotationViewModelTests`。

预期：原有临时任务、轮班调整测试和新增 Deadline 测试全部通过。

## Task 3: 首页逾期分组、红点和无障碍信息

**Files:**

- Modify: `FamilyDuty/Features/Dashboard/DashboardViewModel.swift`
- Modify: `FamilyDuty/Features/Dashboard/DashboardView.swift`
- Modify: `FamilyDutyTests/Features/DashboardViewModelTests.swift`
- Modify: `FamilyDutyTests/AccessibilityTests.swift`
- Modify: `FamilyDutyUITests/DashboardFlowUITests.swift`
- Modify: `FamilyDuty/AppRootView.swift`

### Step 1: 编写失败测试

在 `DashboardViewModelTests` 增加：

1. 逾期分组包含计划日已过且仍 pending 的任务。
2. 明确 Deadline 可使计划日尚未到的任务按 Deadline 判定逾期。
3. 完成和取消的过期任务不进入逾期分组。
4. 临时逾期任务只进入逾期分组，不在临时任务分组重复出现。
5. 逾期任务按有效截止日、计划日期排序。

更新无障碍测试，验证逾期标签包含“已逾期”，非逾期任务仍保持现有标题、负责人和来源信息。

增加 UI 测试种子参数 `-seedOverdueTask`，验证首页显示“已逾期”分组、任务标题和逾期红点；继续保持现有完成任务 UI 测试选择器稳定。

### Step 2: 实现 Dashboard ViewModel

新增 `overdueTasks(from:now:calendar:)`，复用 deadline 服务，只返回 pending 任务。

调整 `temporaryTasks` 排除逾期任务，防止同一任务重复出现；今天和本周稍后列表保持当前日期分组语义。逾期任务统一放入首页列表最前面的“已逾期”分组。

扩展 `accessibilityLabel(for:now:calendar:)`，在逾期时附加“已逾期”，并让调用点传入当前时间和 Calendar；非逾期标签不改变现有语义。

### Step 3: 实现视觉标识和 Deadline 文案

在任务行显示有效截止日期；明确设置的 Deadline 显示所选日期，未设置时显示计划日当天。逾期行在任务标题旁显示红色圆点，并将截止日期文本设为红色；红点设置独立的无障碍标签和标识符。

新增“已逾期” Section，复用现有点击完成/领取和滑动调整行为，不改变完成记录流程。

### Step 4: 运行首页测试

运行 `xcodebuild test -project FamilyDuty.xcodeproj -scheme FamilyDutyTests -destination 'platform=iOS Simulator,name=iPad (10th generation)' -only-testing:FamilyDutyTests/DashboardViewModelTests -only-testing:FamilyDutyTests/AccessibilityTests`，然后运行 Dashboard UI 测试。

预期：逾期任务可见、红色标识存在、无障碍信息正确，原有完成任务流程不回归。

## Task 4: 全量验证与交付检查

**Files:**

- Review: `FamilyDuty/Models/ChoreTask.swift`
- Review: `FamilyDuty/Services/TaskDeadlineService.swift`
- Review: `FamilyDuty/Features/Tasks/TemporaryTaskEditorView.swift`
- Review: `FamilyDuty/Features/Tasks/TaskAdjustmentSheet.swift`
- Review: `FamilyDuty/Features/Dashboard/DashboardView.swift`
- Review: `FamilyDuty/Features/Dashboard/DashboardViewModel.swift`

### Step 1: 重新生成/确认 Xcode 工程

如果源码分组由 `project.yml` 管理，运行 `xcodegen generate`；确认新增 Swift 文件已被 FamilyDuty target 和 FamilyDutyTests target 收录。

### Step 2: 执行完整构建与测试

运行 `xcodebuild -project FamilyDuty.xcodeproj -target FamilyDuty -sdk iphonesimulator build`。

运行 `xcodebuild test -project FamilyDuty.xcodeproj -scheme FamilyDutyTests -destination 'platform=iOS Simulator,name=iPad (10th generation)'`，必要时替换为本机已安装的 iPad 模拟器名称。

### Step 3: 手动验收关键路径

在 iPad 模拟器检查：创建临时任务并设置 Deadline、创建不设置 Deadline 的任务、调整固定任务的 Deadline、跨过截止日后首页出现“已逾期”、完成/取消逾期任务后红色状态消失，以及横竖屏下表单和任务行没有布局截断。

### Step 4: 检查数据兼容与交付说明

确认未设置 Deadline 的旧任务仍按计划日判定，不修改完成记录和轮班顺序；确认没有引入用户隐私数据、配置文件或凭据。若实现过程中出现超出本计划的需求（例如具体时分、重复提醒或规则级默认 Deadline），先返回 PLAN 模式重新确认。

## Final Verification Steps

1. 新增和受影响的 XCTest 全部通过。
2. FamilyDuty target 的模拟器构建无 Swift 编译错误和新增警告。
3. Dashboard UI 测试确认逾期任务可见且完成流程仍可用。
4. 手动检查 iPad 横屏与竖屏、动态字体和 VoiceOver 标签。
