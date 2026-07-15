# Task Presets and Emoji Presentation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在新增临时任务表单中提供常用家务预设下拉框，并通过统一的任务 emoji 展示让首页、任务面板和轮班列表更直观、更有生活感。

**Architecture:** 新增一个无持久化副作用的任务预设目录，保存标准任务名与对应 emoji。新增任务选择预设时只回填现有的 title 字段；列表通过展示层组件按任务名映射 emoji，不修改 SwiftData 模型或已有数据。emoji 作为装饰内容隐藏于 VoiceOver，原有可访问标签和 UI 测试 identifier 继续使用纯文本任务名。

**Tech Stack:** Swift 5、SwiftUI、SwiftData、XCTest、XCUITest、XcodeGen。

## 设计决策与范围

### 方案比较

1. **推荐：展示层目录映射**
   - 预设目录包含标准任务名和 emoji；任务存储仍为纯文本标题。
   - 首页、任务面板、固定轮班列表统一使用任务标题展示组件。
   - 优点是无需 SwiftData schema 迁移，既有任务可立即获得 emoji，且不会改变现有查询、排序、accessibility ID。

2. **把 emoji 直接拼进任务 title 后持久化**
   - 实现最少，但会让同一个任务的标题同时承担数据和展示职责，旧数据、测试字符串和用户自定义标题都需要兼容处理。

3. **给 ChoreTask 增加 emoji 字段**
   - 可扩展性最好，但对本次预设需求过重，需要 SwiftData 迁移和额外编辑流程，暂不采用。

### 预设目录

目录至少包含以下常见任务，并允许后续集中扩展：扫地 🧹、拖地 🧽、擦桌子 🧼、洗碗 🍽️、倒垃圾 🗑️、整理房间 🧺、洗衣服 👕、晾衣服 🧦、擦窗户 🪟、清洁卫生间 🚽、整理冰箱 🧊、浇花 🪴、喂宠物 🐾、整理书桌 📚、更换床单 🛏️、准备晚餐 🍳。自定义任务不强制套用某个家务 emoji，使用通用的 📝 作为展示层 fallback。

选择预设只回填任务名称，不覆盖日期、得分、Deadline 或负责人。用户修改回填后的名称时，下拉框恢复为“选择预设”，避免显示选择状态与实际标题不一致；切换为占位项不清空用户已经输入的标题。

### 视觉与可访问性边界

- 新增表单增加“快速选择任务” Picker，选项显示 emoji 和任务名；表单其他字段保持原有顺序和语义。
- Dashboard、TaskBoard、固定轮班列表及 Dashboard 的近期完成记录使用统一标题组件显示 emoji。
- Dashboard 和 TaskBoard 的状态/空状态区域增加少量独立装饰 emoji，避免把 emoji 作为业务状态的唯一表达。
- emoji Text 使用 accessibilityHidden(true)；外层任务按钮继续使用现有纯文本 accessibilityLabel 和 identifier。
- 保留已有的“首页”“轮班”“设置”“欢迎使用家庭值日”“开始使用”“今天没有待办”等可访问文本，避免破坏现有 UI 测试。
- 不使用固定屏幕尺寸；任务行维持至少 44pt 触控高度，emoji 与标题随 Dynamic Type 自然布局。

## Implementation List

### Task 1: 为预设目录建立可测试的数据层

**Files:**

- Create: FamilyDuty/Features/Tasks/TaskPreset.swift
- Create: FamilyDuty/Features/Tasks/TaskPresetCatalog.swift
- Create: FamilyDutyTests/Features/TaskPresetCatalogTests.swift

**Operations:**

1. 定义 TaskPreset，包含稳定的 id、标准 title 和展示用 emoji，实现 Identifiable 与 Hashable。
2. 定义 TaskPresetCatalog.all，按家庭常用程度排列上述预设；目录不得出现重复标准任务名。
3. 定义 TaskPresetCatalog.preset(named:)，对输入进行首尾空白归一化后查找标准任务。
4. 定义 TaskPresetCatalog.emoji(for:) 和 TaskPresetCatalog.displayTitle(for:)；已知任务使用目录 emoji，未知任务使用 📝；如果标题已经以目录 emoji 开头，不重复添加。
5. 先写失败单元测试，覆盖核心预设存在、emoji 映射、未知任务 fallback、空白归一化和重复 emoji 防护；再实现目录使测试通过。

### Task 2: 在新增临时任务表单中接入下拉预设

**Files:**

- Modify: FamilyDuty/Features/Tasks/TemporaryTaskEditorView.swift:4-68
- Modify: FamilyDutyUITests/AccessibilityUITests.swift or Create: FamilyDutyUITests/TemporaryTaskPresetFlowUITests.swift

**Operations:**

1. 增加可选的 selectedPresetID 状态，并让 Picker 的选项使用稳定的预设 ID；增加 temporary-task-preset-picker accessibility identifier。
2. 在当前任务名称输入框之前增加 Picker("快速选择任务", ...)；占位选项显示“选择预设”，各预设显示对应 emoji 和中文名称。
3. 增加 applyPreset(_:) 私有操作：选择预设时将标准任务名写入 title，不改变日期、得分、Deadline 或负责人。
4. 增加标题变化同步逻辑：用户手动修改标题且不再等于当前预设标题时，将 selectedPresetID 清空；切换占位项不清空标题。
5. 为 Picker 与各预设选项设置不依赖 emoji 的 VoiceOver 文案；保留现有“任务名称”输入框、保存校验和错误提示行为。
6. 增加 UI 测试：打开新增临时任务表单，确认 Picker 存在，选择“扫地”，确认任务名称被回填；再保存并确认现有 dashboard 任务 identifier 仍以纯文本标题工作。

### Task 3: 建立统一的任务标题 emoji 展示组件

**Files:**

- Create: FamilyDuty/Features/Tasks/TaskTitleView.swift
- Modify: FamilyDuty/Features/Dashboard/DashboardView.swift:17-58,62-105
- Modify: FamilyDuty/Features/TaskBoard/TaskBoardView.swift:21-149
- Modify: FamilyDuty/Features/Rotation/RotationListView.swift:14-25

**Operations:**

1. 定义 TaskTitleView(title:)，以 HStack 展示 TaskPresetCatalog.emoji(for:) 和原始标题；emoji 仅作视觉装饰并隐藏于 VoiceOver，标题保持 Dynamic Type 和可换行能力。
2. Dashboard 的待办行、近期完成记录改用该组件；保留 DashboardViewModel.accessibilityLabel(for:) 的纯文本结果，以及 dashboard-task-* 和 history-* identifier。
3. TaskBoard 的待处理、已完成、已取消行改用该组件；状态图标、状态文案、Deadline 颜色逻辑和空状态行为不变。顶部摘要与各 Section 可增加独立的 📋、⏳、✅、🚫 装饰 emoji，但不得以颜色或 emoji 单独表达状态。
4. 固定轮班列表的规则标题也使用同一组件，使预设任务和现有固定任务在不同入口保持一致。
5. 不修改 ChoreTask、ChoreRule、CompletionRecord 字段，不改变任何任务排序、查询或完成流程。

### Task 4: 做小范围的界面文案点缀

**Files:**

- Modify: FamilyDuty/Features/Dashboard/DashboardView.swift
- Modify: FamilyDuty/Features/TaskBoard/TaskBoardView.swift
- Modify: FamilyDuty/Features/Tasks/TemporaryTaskEditorView.swift

**Operations:**

1. 在“快速选择任务”区域使用 🧰 或 ✨ 作为独立装饰 emoji，在首页新增任务入口附近使用 ✨，在任务面板摘要或空状态附近使用 📋/🎉。
2. 保留现有导航 Tab 标签和测试依赖的精确文案，不把 emoji 拼到“设置”“轮班”“首页”等可访问名称中。
3. 控制每个区域最多一个装饰 emoji；emoji 主要承担视觉识别，状态仍由文字和 SF Symbols 表达，避免界面喧闹和依赖颜色。

### Task 5: 回归测试与工程验证

**Files:**

- Modify: FamilyDutyTests/AccessibilityTests.swift only if the shared title component needs focused accessibility coverage.
- Modify: FamilyDutyUITests/AccessibilityUITests.swift only if the preset flow is added there.
- project.yml 不预期修改；XcodeGen 的 sources: FamilyDuty 和 sources: FamilyDutyTests 会自动纳入新增 Swift 文件。

**Verification:**

1. 运行 xcodegen generate，确认新增源文件进入工程。
2. 运行 xcodebuild build-for-testing -project FamilyDuty.xcodeproj -scheme FamilyDutyTests -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/family-duty-derived-data CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=''，确认应用与测试 target 编译通过。
3. 运行 xcodebuild test -project FamilyDuty.xcodeproj -scheme FamilyDutyTests -destination 'platform=iOS Simulator,name=iPad (10th generation)' -derivedDataPath /private/tmp/family-duty-derived-data CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=''；若该模拟器不存在，替换为本机已安装的 iPadOS 17 模拟器并记录替代项。
4. 检查既有 UI 测试：最大 Dynamic Type、横竖屏切换、首页空状态、轮班和设置 Tab、任务完成流程均保持通过。
5. 新增/确认预设选择流程、emoji 映射、任务按钮 accessibility label 和原有 identifier 均通过。
6. 运行 git diff --check，确认无空白错误；完成后再进行一次 iPad 横屏与竖屏的视觉检查，确保任务标题不截断、Picker 可操作、emoji 不挤压日期和 Deadline。

## Final Verification Checklist

- 新增任务表单存在可操作的常用家务预设下拉框。
- 至少覆盖扫地 🧹、拖地、擦桌子等常见任务，并能回填标题。
- 已有任务无需迁移即可在 Dashboard、TaskBoard、固定轮班列表显示一致 emoji。
- 自定义任务仍可自由输入，未知任务使用通用 📝，不污染持久化标题。
- emoji 不改变现有 accessibility label、UI identifier、任务排序和 SwiftData 数据结构。
- XCTest、XCUITest、工程构建与 git diff --check 完成并有实际输出证据。
