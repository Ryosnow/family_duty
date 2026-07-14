# 家庭值日

家庭值日是一款供单个家庭在一台 iPad 上离线使用的 SwiftUI 应用。它支持固定任务按周轮换、单次改派或改期、临时任务、完成记录和本地通知。

## 环境要求

- macOS 与 Xcode 16 或以上版本
- XcodeGen
- iPadOS 17 或以上
- iPad 模拟器或实体 iPad

## 生成并打开工程

```bash
cd /Users/rumor/Documents/Codex/2026-07-14/b
xcodegen generate
open FamilyDuty.xcodeproj
```

选择 `FamilyDuty` App 目标及 iPad 设备后即可运行。工程由 `project.yml` 生成；修改工程配置后应重新执行 `xcodegen generate`。

## 运行测试

```bash
xcodebuild test -project FamilyDuty.xcodeproj \
  -scheme FamilyDutyTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  -derivedDataPath /private/tmp/FamilyDutyDerivedData
```

测试方案包含单元测试和 UI 测试。UI 测试通过 `-uiTesting` 启动参数使用内存数据库，不会读取或修改正式应用数据。

## 使用说明

首次启动时，需要先建立至少一名家庭成员和第一项固定值日。之后可以：

- 在“首页”查看今天、本周稍后、临时任务和近期完成记录。
- 在“轮班”新增或编辑固定任务、参与成员及轮班顺序。
- 对单次任务改派、改期或取消，而不改变后续轮换。
- 新建指定负责人或待领取的临时任务。
- 在“设置”管理成员及本地通知。

## 通知权限

通知仅用于设备本地的每日汇总和逾期提醒。首次启用提醒时，系统会请求通知权限。拒绝权限不会影响任务管理；可以在应用的“通知设置”中打开 iPad 系统设置恢复权限。

## 数据范围

当前版本不包含登录、服务器、多人同步或云端备份。成员、轮班、任务和完成记录仅保存在运行应用的本机 iPad 上。删除应用或抹掉设备可能导致数据永久丢失。
