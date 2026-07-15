# 家庭值日整体 UI 重构实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在不改变现有 SwiftData、轮班、完成、提醒和测试流程的前提下，将家庭值日重塑为有统一视觉身份、适合 iPad 共享查看的家庭任务白板。

**Architecture:** 新增轻量的 SwiftUI DesignSystem 层，集中管理语义颜色、间距、圆角、图标徽章、状态胶囊、任务卡、空状态和进度环。页面从原生 `List/Form` 的默认视觉改为 `ScrollView`、卡片和分组容器；业务查询、ViewModel、服务和持久化模型保持不变，仅调整页面组合与少量展示辅助逻辑。

**Tech Stack:** Swift 5、SwiftUI、SwiftData、SF Symbols、XCTest、XCUITest、XcodeGen；不引入第三方 UI 库或网络字体。

## 视觉方向

采用“家庭共享白板”方向：温暖的纸张背景、深森林绿的主视觉、番茄红的逾期提示和向日葵黄的行动强调。整体保持亲切，但通过留白、分级标题和卡片边界体现秩序感，避免默认蓝色系统页面和装饰性过度。

- 背景：暖纸白；表面：白色或浅薄荷色；主文字：深森林绿；次文字：低饱和灰绿。
- 强调色：向日葵黄用于主要行动和进度；珊瑚红只用于逾期/危险状态；成功状态使用叶绿。
- 版式：iPad 横屏时使用较宽内容列并限制正文最大宽度；竖屏自然收缩。页面级间距采用 8pt 节奏，卡片内边距优先 16/20/24pt。
- 形状：卡片圆角约 18–22pt，阴影只保留极轻的层级提示，避免复杂投影和 3D 效果。
- 签名元素：首页顶部的“今日进度”主卡，以完成进度环、待完成数量和一句家庭提示建立首页记忆点；其余页面沿用相同的状态色和图标徽章。
- 图标：导航、分组、状态和操作全部使用 SF Symbols；预设任务仍可以保留生活化 emoji 作为任务内容的视觉标识，但不再作为导航/Section/状态结构图标。

## 实施清单

### 1. 建立统一 DesignSystem

**Files:**

- Create: `FamilyDuty/DesignSystem/FamilyDutyTheme.swift`
- Create: `FamilyDuty/DesignSystem/FamilyDutyComponents.swift`
- Modify: `FamilyDuty/Features/Tasks/TaskPreset.swift`
- Modify: `FamilyDuty/Features/Tasks/TaskPresetCatalog.swift`
- Modify: `FamilyDuty/Features/Tasks/TaskTitleView.swift`

**Specific operations:**

1. 在 `FamilyDutyTheme.swift` 定义 `FamilyDutyTheme` 命名空间，提供背景、表面、主色、强调色、逾期色、成功色、边框色和次要文字色等语义 token，并为浅色/深色模式提供成对值。
2. 在同一主题层定义 8pt 间距、卡片圆角、图标尺寸、最小交互高度和统一的 `ShapeStyle`/button style 辅助能力；禁止页面继续散落硬编码颜色。
3. 在 `FamilyDutyComponents.swift` 提供以下可复用视图：`FamilyDutyIconBadge`、`FamilyDutySectionHeader`、`FamilyDutyStatusPill`、`FamilyDutyProgressRing`、`FamilyDutyMemberChip`、`FamilyDutyEmptyState` 和 `FamilyDutyTaskCard`。这些组件必须使用 Dynamic Type、最小 44pt 触控高度和可读的 accessibility label。
4. 为任务预设增加与 SF Symbols 对应的 `symbolName` 展示字段或等价映射；不改动现有持久化任务标题和测试中使用的标题字符串。
5. `TaskTitleView` 改为“图标徽章 + 标题”的统一排列，并保留对历史 emoji 标题的解析兼容；历史数据不会因为换肤而被修改。

**Verification:** 新增组件仅负责展示，不访问 SwiftData；先运行 `xcodegen generate` 和应用编译，确认新目录下的 Swift 文件自动加入 target。

### 2. 重做根导航的视觉层

**Files:**

- Modify: `FamilyDuty/AppRootView.swift`

**Specific operations:**

1. 保留 `MainTabView` 的四个入口、顺序和现有 accessibility identifiers，确保已有 UI 测试无需通过文字猜测导航结构。
2. 为 TabView 应用主题 tint 和统一的 SF Symbols；为“任务面板”补充稳定的 `task-board-tab` identifier，但不删除“首页”“任务面板”“轮班”“设置”文字标签。
3. 只调整导航外观与容器背景，不修改首次启动判断和 UI 测试种子逻辑。

### 3. 重做首页 Dashboard

**Files:**

- Modify: `FamilyDuty/Features/Dashboard/DashboardView.swift`
- Modify: `FamilyDuty/Features/Dashboard/DashboardViewModel.swift` only when a展示统计 helper is required
- Modify: `FamilyDutyTests/Features/DashboardViewModelTests.swift` only for any new纯计算统计 helper
- Modify: `FamilyDutyUITests/DashboardFlowUITests.swift`
- Modify: `FamilyDutyUITests/AccessibilityUITests.swift`

**Specific operations:**

1. 将首页主体从默认 `List` 改为带适应性内边距的 `ScrollView` 和 `LazyVStack`，保持现有 overdue、today、later-this-week、temporary 和 recent history 的数据来源与顺序。
2. 增加首页顶部 `TodayProgressHeader` 视觉区域：展示当前日期、今日待处理数量、已完成数量或进度环；当没有任务时转为明确的空状态，而不是显示空白卡片。
3. 将每个任务改为 `FamilyDutyTaskCard`：突出任务标题和负责人，日期/Deadline 作为元信息，逾期使用红色状态胶囊和 SF Symbol，不再使用小红圆点作为唯一状态信息。
4. 将分组标题改为 `FamilyDutySectionHeader`，使用 `clock.badge.exclamationmark`、`calendar`、`calendar.badge.clock`、`sparkles`、`checkmark.circle` 等语义图标，并保留原有中文标题。
5. 将近期完成记录改为更易扫读的紧凑历史卡，展示完成状态、任务、完成者和时间；保留 `history-*` identifiers。
6. 新增临时任务操作保持原有 `dashboard-add-temporary` identifier，并将其呈现为首页主卡中的明确次级行动按钮。
7. 通过 `@Environment(\\.accessibilityReduceMotion)` 控制进度环或卡片出现动画；减少动态效果时保持静态布局和同等信息量。

### 4. 重做任务面板

**Files:**

- Modify: `FamilyDuty/Features/TaskBoard/TaskBoardView.swift`
- Modify: `FamilyDuty/Features/TaskBoard/TaskBoardViewModel.swift` only if display-specific grouping metadata is needed
- Modify: `FamilyDutyUITests/TaskBoardFlowUITests.swift`

**Specific operations:**

1. 保留 `TaskBoardViewModel` 当前的当天筛选和三种状态分组，不增加历史日期浏览功能。
2. 顶部改为“今日任务”摘要卡，显示总数和三种状态数量；无任务时使用 `FamilyDutyEmptyState`。
3. 将待处理、已完成、已取消改为统一的卡片 Section；状态颜色、图标和文案三者同时表达状态，避免只依赖颜色。
4. 待处理卡片继续支持点击领取/完成和 swipe 调整；已完成和已取消卡片保持只读。保留 `task-board`、`task-board-task-*` 和“确认完成”测试可定位的行为。
5. 删除面板中的 emoji Section 图标，改用 SF Symbols；维持完成者、完成时间、取消说明和 Deadline 的现有业务文案。

### 5. 重做固定轮班页

**Files:**

- Modify: `FamilyDuty/Features/Rotation/RotationListView.swift`
- Modify: `FamilyDuty/Features/Rotation/RuleEditorView.swift`
- Modify: `FamilyDuty/Features/Rotation/MemberOrderEditorView.swift`
- Modify: `FamilyDuty/Features/Rotation/RotationViewModel.swift` only if the view needs a纯展示 summary helper
- Modify: `FamilyDutyUITests/AccessibilityUITests.swift`

**Specific operations:**

1. 将固定轮班列表从默认 `List` 改为卡片列表，每张卡展示任务图标、标题、下一位负责人、启用/停用状态和可点击的编辑 affordance。
2. 空状态使用统一的 `FamilyDutyEmptyState`，主行动仍为 `rotation-add-rule`。
3. RuleEditor 保留所有字段和保存校验，将 `Form` 的 Section 视觉统一为主题表面卡；保存/取消按钮仍使用系统 toolbar 位置，确保 iPad 表单行为可预测。
4. MemberOrderEditor 保留拖动排序，增加成员头像/首字母徽章和更清晰的拖动提示；不改变 `participantIDs` 的业务顺序。

### 6. 重做设置与所有表单 Sheet

**Files:**

- Modify: `FamilyDuty/Features/Settings/SettingsView.swift`
- Modify: `FamilyDuty/Features/Settings/NotificationSettingsView.swift`
- Modify: `FamilyDuty/Features/Settings/MemberEditorView.swift`
- Modify: `FamilyDuty/Features/Setup/OnboardingView.swift`
- Modify: `FamilyDuty/Features/Tasks/CompletionSheet.swift`
- Modify: `FamilyDuty/Features/Tasks/ClaimTaskSheet.swift`
- Modify: `FamilyDuty/Features/Tasks/TaskAdjustmentSheet.swift`
- Modify: `FamilyDuty/Features/Tasks/TemporaryTaskEditorView.swift`
- Modify: related UI tests only when layout/container changes require more stable identifiers

**Specific operations:**

1. Settings 页面改为“家庭成员”和“提醒”两块主题卡片；成员行增加头像徽章、姓名和编辑 affordance，保留删除保护流程与 `settings-add-member` identifier。
2. NotificationSettings、MemberEditor、CompletionSheet、ClaimTaskSheet、TaskAdjustmentSheet 和 TemporaryTaskEditor 保留原字段、验证、错误提示和提交服务，只统一背景、Section 标题、输入控件间距、按钮语义和 sheet 顶部层级。
3. 将 `TemporaryTaskEditorView` 的预设选择从带 emoji 的长文本改为可扫读的图标/标题选择，但保持 `temporary-task-preset-picker`、`temporary-task-preset-*` 和“任务名称” accessibility identifiers。
4. Onboarding 改为欢迎头图式的主题卡 + 分步表单布局，保留“成员姓名”“首个固定任务”“开始使用”等 UI 测试入口；不得改变首次创建成员和规则的业务流程。
5. 所有 Sheet 的主按钮在保存/确认期间保持禁用或显示处理反馈，错误信息仍以可访问的 alert 传达。

### 7. 测试与视觉验收

**Files:**

- Modify: `FamilyDutyTests/AccessibilityTests.swift` for semantic label coverage
- Modify: `FamilyDutyUITests/AppLaunchUITests.swift`
- Modify: `FamilyDutyUITests/DashboardFlowUITests.swift`
- Modify: `FamilyDutyUITests/TaskBoardFlowUITests.swift`
- Modify: `FamilyDutyUITests/AccessibilityUITests.swift`
- Create: `FamilyDutyUITests/FamilyDutyVisualFlowUITests.swift` only if the existing UI tests cannot cover the new primary-card structure

**Verification steps:**

1. 先执行 `xcodegen generate`，再执行无签名 iPad Simulator build。
2. 执行现有单元测试和 UI 测试，确认业务行为、seed 数据、导航和 accessibility identifiers 未回归。
3. 通过 UI 测试覆盖首页空状态、首页任务卡、任务面板三种状态、固定轮班空状态、设置成员入口和首次引导。
4. 在 iPad 竖屏与横屏检查：内容不被 safe area 遮挡、卡片不发生横向溢出、主要操作保持至少 44pt 高度、长文本和 Dynamic Type 不截断关键操作。
5. 分别检查浅色和深色模式：主文字对比度至少 4.5:1，次文字至少 3:1，逾期/完成/取消不能只依赖颜色表达。
6. 使用减少动态效果和最大辅助功能字号运行关键 UI 流程，确认无因固定高度或动画导致的操作不可用。
7. 运行 `git diff --check`，并在最终交付前使用 `superpowers:verification-before-completion` 复核构建和测试证据。

## 明确不做的事情

- 不修改 SwiftData 模型、轮班算法、Deadline 规则、通知调度或完成服务。
- 不加入第三方图标库、远程字体、联网图片、登录或同步功能。
- 不新增历史日期浏览、拖拽看板或复杂动画；本次重点是视觉层级、可扫读性和一致性。
- 不删除现有 accessibility identifiers；若新组件改变了可访问性树，只通过稳定 identifier 和更完整 label 兼容现有 UI 测试。

## 最终交付标准

首页能够在首屏清楚传达“今天要做什么、完成了多少、下一步做什么”；任务面板能够在不阅读长文案的情况下区分三种状态；轮班与设置页面拥有相同的视觉语言；所有现有功能和测试保持可用；浅色/深色、横竖屏、Dynamic Type、减少动态效果和空状态均经过验证。
