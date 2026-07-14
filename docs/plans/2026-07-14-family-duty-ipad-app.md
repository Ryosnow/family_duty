# 家庭值日 iPad App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建一个单台 iPad 离线使用的家庭值日应用，支持按周轮班、临时插入任务、完成记录和本地提醒。

**Architecture:** 使用 SwiftUI 建立适配 iPad 横竖屏的三栏/标签式界面；使用 SwiftData 将成员、轮班规则、任务实例与完成记录持久化在设备本地。将“规则”和“实际任务”分离：固定规则负责计算每周负责人，手动调整与临时任务写为独立任务实例，避免影响后续轮换。

**Tech Stack:** Swift 6、SwiftUI、SwiftData、UserNotifications、XCTest、Xcode（最新稳定版；部署目标 iPadOS 17 或以上）。

**范围与验收标准：**

- 单个家庭共用一台 iPad；不含登录、多人同步、服务器或云端备份。
- 初次使用可建立家庭成员及固定值日；首页能明确看到今日、本周稍后、临时任务与近期完成记录。
- 固定任务按周和成员顺序轮换；某一周的改派、改期、取消不改变后续周次的顺序。
- 可临时新增任务并指定负责人或设为待领取；临时任务不影响固定轮班。
- 完成任务必须记录完成者与完成时间；可查看近期记录。
- 可设置每日汇总提醒与逾期提醒；通知被拒绝不影响其余功能，并展示恢复权限入口。

### Task 1: 创建 iPad 项目与应用骨架

**Files:**
- Create: `FamilyDuty/FamilyDutyApp.swift`
- Create: `FamilyDuty/AppRootView.swift`
- Create: `FamilyDuty/Assets.xcassets`
- Create: `FamilyDutyTests/FamilyDutyTests.swift`
- Create: `FamilyDuty.xcodeproj/project.pbxproj`

**Step 1: 创建 SwiftUI App 工程**

在 Xcode 新建名为 `FamilyDuty` 的 iPad App，选择 SwiftUI、SwiftData、Swift 和 iPadOS 17 部署目标；配置应用标识符与中文显示名称“家庭值日”。

**Step 2: 添加根导航容器**

实现 `AppRootView`，在横屏时使用 `NavigationSplitView`，窄屏时回退为 `TabView`；入口包括“首页”“轮班”“设置”。

**Step 3: 建立空状态测试**

编写启动和根导航存在性的 UI 测试；运行测试，确认初始工程在 iPad 模拟器通过。

**Step 4: 提交检查点**

在 Git 仓库中提交“chore: create iPad app shell”；若工作目录尚未初始化 Git，记录该前置条件，不创建实现提交。

### Task 2: 定义 SwiftData 领域模型与持久化容器

**Files:**
- Create: `FamilyDuty/Models/FamilyMember.swift`
- Create: `FamilyDuty/Models/ChoreRule.swift`
- Create: `FamilyDuty/Models/ChoreTask.swift`
- Create: `FamilyDuty/Models/CompletionRecord.swift`
- Create: `FamilyDuty/Models/TaskStatus.swift`
- Create: `FamilyDuty/Services/ModelContainerFactory.swift`
- Create: `FamilyDutyTests/Models/ModelPersistenceTests.swift`

**Step 1: 写失败测试**

覆盖成员、轮班规则、任务实例和完成记录的保存与重新读取；验证任务可关联规则但临时任务可没有规则。

**Step 2: 实现数据对象**

定义模型字段：成员（标识、姓名、颜色/头像代号、排序）；规则（标题、星期、参与成员顺序、起始周、启用状态）；任务（标题、计划日期、负责人、来源规则、是否临时、状态、覆盖原因）；完成记录（任务、实际完成人、完成时间）。

**Step 3: 配置容器和关系删除策略**

在 App 入口注入 model container；成员删除前由业务层检查任务和规则引用，模型层不静默丢失历史完成记录。

**Step 4: 运行测试**

运行 `xcodebuild test`，确认持久化与关系测试通过。

### Task 3: 实现轮班计算与任务生成服务

**Files:**
- Create: `FamilyDuty/Services/CalendarProvider.swift`
- Create: `FamilyDuty/Services/RotationScheduler.swift`
- Create: `FamilyDuty/Services/TaskGenerationService.swift`
- Create: `FamilyDutyTests/Services/RotationSchedulerTests.swift`
- Create: `FamilyDutyTests/Services/TaskGenerationServiceTests.swift`

**Step 1: 写轮换失败测试**

测试从规则起始周计算负责人、跨年周数、成员顺序循环、规则停用，以及没有成员时不生成任务。

**Step 2: 实现 `RotationScheduler.assignee(for:weekOf:calendar:)`**

让它根据起始周至目标周的完整周数取模选择负责人；所有日期计算使用可注入的日历与时区，避免依赖设备当前语言设置。

**Step 3: 写覆盖与临时任务失败测试**

测试同一规则和日期已存在改派/改期/取消覆盖时不创建重复任务，并测试临时任务永远不进入轮换规则。

**Step 4: 实现 `TaskGenerationService.ensureTasks(through:)`**

在应用启动、规则修改与周切换时生成未来四周固定任务；保留已有覆盖任务，且不更改已完成任务。

**Step 5: 运行服务测试**

执行指定 XCTest 目标，确认轮班、覆盖和临时任务场景全部通过。

### Task 4: 实现首页、完成流程与近期记录

**Files:**
- Create: `FamilyDuty/Features/Dashboard/DashboardView.swift`
- Create: `FamilyDuty/Features/Dashboard/TaskCardView.swift`
- Create: `FamilyDuty/Features/Dashboard/CompletionSheet.swift`
- Create: `FamilyDuty/Features/Dashboard/RecentHistoryView.swift`
- Create: `FamilyDuty/Features/Dashboard/DashboardViewModel.swift`
- Create: `FamilyDutyTests/Features/DashboardViewModelTests.swift`
- Create: `FamilyDutyUITests/DashboardFlowUITests.swift`

**Step 1: 写首页分类失败测试**

测试任务按“今天”“本周稍后”“临时任务”分类，完成项不显示在待办区域，近期记录按完成时间倒序且限制显示数量。

**Step 2: 实现首页与大尺寸任务卡**

以可访问性字号构建任务卡，展示标题、负责人、日期、来源和状态；首页顶部展示周范围和待完成数。

**Step 3: 实现完成确认**

点击完成后打开确认页，默认当前负责人、允许选择实际完成人；保存时原子更新任务状态并创建完成记录，失败时显示错误且保留未完成状态。

**Step 4: 编写并运行 UI 测试**

覆盖完成一个任务后其从待办消失、近期记录出现完成者与时间；在 iPad 横竖屏模拟器运行。

### Task 5: 实现固定轮班管理与手动调整

**Files:**
- Create: `FamilyDuty/Features/Rotation/RotationListView.swift`
- Create: `FamilyDuty/Features/Rotation/RuleEditorView.swift`
- Create: `FamilyDuty/Features/Rotation/MemberOrderEditorView.swift`
- Create: `FamilyDuty/Features/Tasks/TaskAdjustmentSheet.swift`
- Create: `FamilyDuty/Features/Rotation/RotationViewModel.swift`
- Create: `FamilyDutyTests/Features/RotationViewModelTests.swift`

**Step 1: 写规则编辑失败测试**

覆盖创建规则、选择星期、设置起始负责人、重排成员、停用规则，并确认保存后触发未来任务生成。

**Step 2: 实现轮班管理页面**

展示每项固定任务的下一次负责人；编辑页强制至少一名成员和一个任务名称，保存后重算未覆盖的未来任务。

**Step 3: 写手动调整失败测试**

覆盖改派、改期、取消一次固定任务；验证同一规则的下一个周次负责人保持原顺序。

**Step 4: 实现 `TaskAdjustmentSheet`**

允许对单次任务选择新负责人、日期或取消原因；只更新当前任务实例，不编辑轮班规则。

**Step 5: 运行功能测试**

在服务和视图模型测试中确认手动调整不会破坏轮换。

### Task 6: 实现临时任务与待领取任务

**Files:**
- Create: `FamilyDuty/Features/Tasks/TemporaryTaskEditorView.swift`
- Create: `FamilyDuty/Features/Tasks/ClaimTaskSheet.swift`
- Create: `FamilyDuty/Features/Tasks/TemporaryTaskViewModel.swift`
- Create: `FamilyDutyTests/Features/TemporaryTaskViewModelTests.swift`

**Step 1: 写临时任务失败测试**

覆盖创建带负责人、无负责人待领取、指定日期的临时任务；验证其来源为空、轮班规则不变。

**Step 2: 实现新增与领取流程**

首页“新增临时任务”按钮打开编辑页；未指派任务允许选择家庭成员领取，领取后立即出现在该成员的任务卡上。

**Step 3: 运行测试**

确认临时任务创建、领取、完成和记录流程都通过，且固定任务生成结果不变。

### Task 7: 实现成员管理、首次引导与删除保护

**Files:**
- Create: `FamilyDuty/Features/Setup/OnboardingView.swift`
- Create: `FamilyDuty/Features/Settings/SettingsView.swift`
- Create: `FamilyDuty/Features/Settings/MemberEditorView.swift`
- Create: `FamilyDuty/Services/MemberDeletionService.swift`
- Create: `FamilyDutyTests/Services/MemberDeletionServiceTests.swift`
- Create: `FamilyDutyUITests/OnboardingUITests.swift`

**Step 1: 写首次引导失败测试**

覆盖空数据库显示引导、至少创建一名成员才能结束引导，以及创建首个固定任务后进入首页。

**Step 2: 实现首次引导和设置页**

首次启动引导用户输入家庭成员和第一个固定任务；设置页提供成员新增、改名、排序和提醒配置入口。

**Step 3: 写删除保护失败测试**

测试被规则、未完成任务或历史记录引用的成员不能直接删除；服务需返回具体引用说明。

**Step 4: 实现删除保护与改派提示**

删除前展示需要先改派的未完成任务和规则；历史完成记录保留完成者快照。

**Step 5: 运行引导与删除测试**

确认首次启动、成员管理和数据保护流程通过。

### Task 8: 实现本地通知与通知设置

**Files:**
- Create: `FamilyDuty/Services/NotificationAuthorizationService.swift`
- Create: `FamilyDuty/Services/NotificationScheduler.swift`
- Create: `FamilyDuty/Features/Settings/NotificationSettingsView.swift`
- Create: `FamilyDutyTests/Services/NotificationSchedulerTests.swift`

**Step 1: 写通知计划失败测试**

使用通知中心协议的测试替身，验证每日汇总只包含当天未完成任务、逾期提醒只针对未完成任务、重排后不残留旧请求。

**Step 2: 实现授权与计划服务**

定义 `requestAuthorization()`、`refreshSchedule(for:)` 与 `cancelManagedRequests()`；首次需要提醒时请求权限，日常在任务或设置变动后刷新。

**Step 3: 实现通知设置页**

提供总开关、每日提醒时刻、逾期提醒时刻；权限拒绝时展示状态与系统设置入口，不阻断任务管理。

**Step 4: 运行通知测试**

确认测试替身收到正确时间和内容；在模拟器手动验证授权提示与设置状态。

### Task 9: 无障碍、错误状态和最终验证

**Files:**
- Modify: `FamilyDuty/AppRootView.swift`
- Modify: `FamilyDuty/Features/Dashboard/DashboardView.swift`
- Create: `FamilyDutyTests/AccessibilityTests.swift`
- Create: `README.md`

**Step 1: 增加失败与空状态覆盖**

测试保存失败、没有今日任务、通知被拒绝、无成员和轮班无成员等状态，确保均提供可操作提示。

**Step 2: 实现错误呈现与无障碍标识**

为关键按钮和任务卡补充可访问性标签、动态字体和足够触控区域；所有数据写入错误使用明确提示且不伪造成功状态。

**Step 3: 执行完整验证**

在 iPadOS 17+ 模拟器运行全部单元测试和 UI 测试，检查横竖屏、最大动态字体、首次引导、轮班调整、临时任务、完成记录和通知设置。

**Step 4: 编写交付说明**

在 README 记录最低系统版本、Xcode 打开方式、通知授权说明和“本版仅存储于本机 iPad”的数据范围。

**Step 5: 提交检查点**

在已初始化的 Git 仓库中提交“feat: deliver family duty iPad app”；提交前仅在全部验证通过时执行。

## Final Verification Steps

1. 冷启动应用：确认首次引导可完成，首页没有重复生成的任务。
2. 建立两人轮换的每周扫地：连续检查至少四周负责人交替正确。
3. 改派其中一周：确认该周显示新负责人，下一周仍回到原本顺序。
4. 插入一次临时扫地并完成：确认固定轮班不受影响，首页出现带完成者和完成时间的近期记录。
5. 修改提醒时刻、完成或改期任务：确认旧的应用通知被取消并替换为新计划。
6. 拒绝通知权限、旋转屏幕、启用最大字体：确认关键流程仍可用且布局不遮挡操作。

## 执行进度与当前状况（2026-07-14）

### 已完成

- 已创建 XcodeGen 工程定义 `project.yml`、生成的 `FamilyDuty.xcodeproj`，部署目标为 iPadOS 17。
- 已创建原生 SwiftUI App 骨架，包含“首页”“轮班”“设置”入口，并配置中文应用名称“家庭值日”。
- 已添加应用 `Info.plist`，并为单元测试和 UI 测试目标启用自动生成 `Info.plist`，解决测试包签名配置失败问题。
- 已实现 SwiftData 数据模型：`FamilyMember`、`ChoreRule`、`ChoreTask`、`CompletionRecord`、`TaskStatus`，以及持久化和内存测试容器工厂。
- 已实现轮班算法 `RotationScheduler` 和 `TaskGenerationService`：按规则起始周及成员顺序生成未来四周任务，并避免覆盖手动调整和已完成实例。
- 已为轮班成员 UUID 顺序建立独立持久化字段，避免 SwiftData 关系数组重排导致负责人顺序不稳定。
- 已实现首页待办、完成确认、实际完成人选择、最近八条完成记录和完成者姓名快照；旧数据库中的历史记录可回退到关联成员姓名。
- 已实现首页完成流程 UI 测试，并通过独立内存数据库隔离 UI 测试运行数据。
- 已实现固定轮班列表、规则新增与编辑、星期选择、成员选择及排序、规则启用和停用。
- 已实现单次任务改派、改期和取消；调整只修改当前任务实例，不影响后续周次轮换。
- 已实现临时任务创建、指定负责人、待领取任务和领取流程；临时任务不关联固定规则。
- 已实现首次引导：空数据库时创建首名成员和第一项固定轮班后进入主界面。
- 已实现设置页成员新增、改名、排序和删除保护；规则、待办或历史记录仍引用成员时展示具体阻止原因。
- 已实现本地通知授权与调度：每日汇总、逾期待办提醒、旧托管请求清理、权限拒绝提示和系统设置入口。
- 已在应用根层监听任务及提醒设置变化，任务完成、改派、改期或新增后会自动刷新托管通知请求。
- 已为 UI 测试启动提供内存 SwiftData 容器与确定性数据夹具，避免模拟器残留数据造成测试波动。
- 已将首页待办拆分为“今天”“本周稍后”和“临时任务”，并为各区域及近期记录补充明确空状态。
- 已实现完成操作的原子保存与失败回滚：保存失败时恢复待办状态、移除未保存记录并保留确认页面展示错误。
- 已为任务卡和首页、轮班、设置的关键操作补充无障碍标签、提示和稳定测试标识。
- 已完成最大辅助字号下的 iPad 横竖屏 UI 测试，确认任务卡和关键入口仍可见、可点击。
- 已清理 `Info.plist` 中冗余的 `UIDeviceFamily`，设备范围由 `TARGETED_DEVICE_FAMILY` 统一配置。
- 已编写 `README.md`，记录环境要求、工程生成、测试命令、通知权限和仅本机存储的数据范围。

### 已完成验证

- 已在 `iPad Pro 13-inch (M4)`、iOS 18.0 模拟器运行完整 `FamilyDutyTests` 方案。
- 单元测试共 29 个，0 失败；覆盖持久化、轮班计算、任务生成去重与覆盖保留、规则编辑、单次调整、临时任务、成员删除保护、通知调度、Dashboard 分类、完成失败回滚和通知权限提示。
- UI 测试共 5 个，0 失败；覆盖主导航、首页完成流程、首次引导、空状态、最大辅助字号和横竖屏切换。
- 最新完整测试最终输出为 `TEST SUCCEEDED`。
- 已验证新增完成者快照字段可以从旧模拟器数据库轻量迁移，不再因必填字段缺失导致容器加载失败。
- 已修复此前出现的工程、编译和测试问题：应用/测试 `Info.plist` 缺失、SwiftData 容器挂载、关系数组顺序不稳定、测试数据库污染、iPad 自适应 `TabView` 查询方式和旧数据库迁移失败。

### 当前验证命令

```bash
cd /Users/rumor/Documents/Codex/2026-07-14/b
xcodegen generate
xcodebuild test -project FamilyDuty.xcodeproj \
  -scheme FamilyDutyTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  -derivedDataPath /private/tmp/FamilyDutyDerivedData
```

### 未完成工作

自动化实现与测试范围内已无未完成项。发布到家庭使用的实体 iPad 前仍建议人工确认：

1. 通知首次授权的允许和拒绝流程，以及系统设置恢复入口。
2. 每日汇总和逾期提醒在实体设备上的实际送达时间与文案。
3. 最大辅助字号、横竖屏和不同 iPad 尺寸下的最终视觉效果。
4. 删除应用前的数据丢失提示是否符合家庭成员的使用预期。

### 已知注意事项

- 当前工作目录不是 Git 仓库，因此计划中的工作树和提交检查点未执行。
- UI 测试依赖 `-uiTesting` 启动参数创建内存数据库；正式应用仍使用设备本地持久化数据库。
