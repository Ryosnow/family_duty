# 家庭值日微信小程序

这是 FamilyDuty 的原生微信小程序实现，使用 WXML、WXSS 和 TypeScript。成员、规则、任务和完成记录只保存在当前微信客户端，不包含登录、云数据库或多人同步。

## 功能

- 首次引导、成员颜色与排序管理。
- 首页的逾期、今天、本周稍后、临时任务和近期完成。
- 今日任务面板，以及领取、完成、撤销、改派、改期、Deadline、分值和单次取消。
- 固定规则、成员轮换顺序、启用/停用和未来八周任务生成。
- 日/周/月完成数量、得分、计划工作量、Canvas 趋势和历史筛选。
- 应用内每日汇总和逾期提醒。
- 与 iPad `LocalBackupService` schema version 1 兼容的 JSON 导入导出。

## 本地开发

```bash
cd FamilyDutyMiniProgram
npm install
npm run verify
```

在微信开发者工具中导入 `FamilyDutyMiniProgram` 目录。`project.config.json` 的 `miniprogramRoot` 已指向 `miniprogram/`，默认 `appid` 为 `touristappid`；真机预览或发布前替换为自己的小程序 AppID。

开发者工具不在仓库中，且本项目不包含上传私钥、AppSecret 或云开发环境配置。

## 数据与提醒限制

- 微信本地 Storage 总容量通常为 10MB。本项目以分块快照保存，提交失败时继续使用上一份完整数据。
- 达到 8MB 后设置页会提示导出备份。微信清理缓存或删除小程序可能造成数据丢失。
- 提醒只在小程序打开或回到前台时检查，不会在后台发送微信通知。
- 导出文件通过微信文件转发，导入从微信会话选择 JSON；恢复前会全量验证并要求确认。

## 目录

```text
miniprogram/
├── components/       任务卡等共享组件
├── custom-tab-bar/   五项纯文字导航
├── data/             版本化分块快照仓库
├── domain/           模型、日期、服务、选择器与校验
├── pages/            引导、首页、任务、报表、历史、轮班和设置
├── store/            全局 AppStore
└── assets/icons/     本地 SVG 图标
tests/                Vitest 领域与存储回归测试
```
