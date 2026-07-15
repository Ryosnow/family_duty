# 家庭值日

家庭值日是一款供单个家庭在一台 iPad 上离线使用的 SwiftUI 应用。它支持固定任务按周轮换、单次改派或改期、临时任务、完成记录和本地通知。

## 环境要求

- macOS 与 Xcode 16 或以上版本
- XcodeGen
- iPadOS 17 或以上
- iPad 模拟器或实体 iPad

## 生成并打开工程

```bash
cd /Users/rumor/Desktop/mine/family_duty
xcodegen generate
open FamilyDuty.xcodeproj
```

选择 `FamilyDuty` App 目标及 iPad 设备后即可运行。工程由 `project.yml` 生成；修改工程配置后应重新执行 `xcodegen generate`。

## 在 iPad 模拟器中启动 UI

1. 按照上面的命令生成并打开工程。
2. 在 Xcode 顶部的 Scheme 中选择 `FamilyDuty`。
3. 在运行设备中选择任意安装了 iPadOS 17 或以上版本的 iPad 模拟器，例如 `iPad Pro 13-inch (M4)`。
4. 按 `Command + R`，Xcode 会构建应用、启动模拟器并打开“家庭值日”。
5. 首次进入时按引导创建家庭成员和固定值日，即可进行手动 UI 测试。

如果设备列表中没有 iPad 模拟器，可在 Xcode 的 `Settings > Platforms` 下载 iOS Simulator Runtime，再通过 `Window > Devices and Simulators` 创建 iPad 模拟器。

## 运行自动化测试

```bash
xcodebuild test -project FamilyDuty.xcodeproj \
  -scheme FamilyDutyTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  -derivedDataPath /private/tmp/FamilyDutyDerivedData
```

测试方案包含单元测试和 UI 测试。也可以在 Xcode 中选择 `FamilyDutyTests` Scheme 后按 `Command + U` 运行全部测试，或在 Test Navigator 中单独运行 `FamilyDutyUITests`。

UI 测试通过 `-uiTesting` 启动参数使用内存数据库，不会读取或修改正式应用数据。如果命令中的模拟器名称与本机不一致，可先运行下面的命令查看可用设备，再替换 `-destination` 中的名称：

```bash
xcrun simctl list devices available
```

## 在实体 iPad 上测试

准备条件：iPad 需要运行 iPadOS 17 或以上版本，并通过 USB 连接 Mac，或已在 Xcode 中启用无线调试。

1. 在 iPad 上打开 `设置 > 隐私与安全性 > 开发者模式`，按照系统提示重启并确认启用。如果没有“开发者模式”，先将设备连接 Xcode 一次。
2. 在 Mac 上打开 `FamilyDuty.xcodeproj`，在 Xcode 的 `Settings > Accounts` 登录 Apple ID。
3. 选择项目中的 `FamilyDuty` Target，打开 `Signing & Capabilities`，勾选 `Automatically manage signing`，并选择自己的 Team。
4. 如果 `com.familyduty.app` 已被其他开发者占用，将 Bundle Identifier 改为自己的唯一标识，例如 `com.<你的名字>.familyduty`。由于工程由 XcodeGen 管理，若要永久保留该修改，应同时更新 `project.yml` 中的 `PRODUCT_BUNDLE_IDENTIFIER`，然后重新运行 `xcodegen generate`。
5. 在 Xcode 顶部选择已连接的 iPad，按 `Command + R`。首次连接时，需要在 iPad 上选择“信任此电脑”，并等待 Xcode 完成设备准备和安装。
6. 如果 iPad 提示开发者不受信任，进入 `设置 > 通用 > VPN 与设备管理`，信任对应的开发者证书，然后重新打开应用。

使用免费的个人 Apple ID 签名时，安装通常有时间限制，过期后需要重新连接 Xcode 构建安装。真机运行使用设备上的本地数据库；删除应用会一并删除测试数据。

建议在真机上至少验证以下场景：

- 完成首次引导，创建两名以上成员和一个固定值日。
- 检查首页、轮班和设置页面在横屏、竖屏下的布局与操作。
- 完成、撤销、改派、改期和取消任务，确认后续轮换不受单次调整影响。
- 创建“待领取”和指定负责人的临时任务，并完成领取流程。
- 启用通知并授权，检查系统设置跳转、每日汇总和逾期提醒。
- 结束应用后重新打开，确认成员、任务和完成记录仍然存在。

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
