# 本周计划工作量 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在报表页展示当前自然周内每位成员已分配的任务数和计划分值，帮助家庭识别值日分配是否均衡。

**Architecture:** 新增纯函数式的 `PlannedWorkloadViewModel`，从现有 `ChoreTask`、`FamilyMember` 和注入的 `Calendar` 计算成员计划工作量，不新增 SwiftData 字段。新增独立的报表卡片，保留现有完成工作量报表和任务面板行为不变。

**Tech Stack:** Swift 5、SwiftUI、SwiftData、Foundation Calendar、XCTest、XCUITest。

## 行为约定

- 统计当前日期所在的自然周，使用注入的 `Calendar` 计算周边界。
- 固定任务和临时任务都纳入统计。
- 只统计有负责人且负责人仍是当前家庭成员的任务；待领取任务不归属于任何成员。
- 待处理、已完成和已取消任务都属于“计划负担”，因此都计入任务数量和任务分值。
- 使用 `ChoreTask.score` 作为任务当前实例的计划分值快照。
- 没有任务的成员仍显示为 0 项、0 分，并保持成员排序。

## 受影响文件

- Create: `FamilyDuty/Features/Reports/PlannedWorkloadViewModel.swift`
- Create: `FamilyDuty/Features/Reports/PlannedWorkloadSummaryView.swift`
- Modify: `FamilyDuty/Features/Reports/ReportsView.swift`
- Create: `FamilyDutyTests/Features/PlannedWorkloadViewModelTests.swift`
- Modify: `FamilyDutyUITests/ReportsFlowUITests.swift`
- Modify: `README.md`
- Create: `docs/plans/2026-07-15-planned-workload.md`

## 验证

- 先运行新增单元测试确认缺少实现时失败。
- 实现后运行新增单元测试和报表 UI 测试。
- 运行完整 `FamilyDutyTests` Scheme。
- 执行 `git diff --check`，并确认没有修改 SwiftData 模型、备份格式、轮班算法或通知逻辑。
