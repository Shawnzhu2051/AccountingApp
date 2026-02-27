# PROJECT_CONTEXT – AccountingApp

这份文件是“项目脑 / 上下文快照”。
目标：隔很久回来，或换一个 AI/人接手时，5 分钟内恢复状态并继续开发。

## 1. 项目一句话
一个轻量、极客风的 iOS 记账 App（SwiftUI + SwiftData + Charts），聚焦 MVP：记账/流水/报表/导出/导入。

## 2. 当前已实现（✅）
### 2.1 记账（新增流水）
- 必填字段：分类、币种(SGD/RMB/USD)、收入/支出、时间（到天，默认今天）、项目（默认“日常项目”可选）、金额
- 备注可为空
- 分类体系：
  - 支出：一级+二级（娱乐/购物/日常/出行/人情/金融/医疗/住房…）
  - 收入：工资收入/红包收入/奖金收入/其他收入
- UI：卡片式“极客风”，金额用 primary，收入/支出用 badge 表达语义（更符合 HIG 克制风格）

关键文件：
- `AccountingApp/Views/AddTransactionView.swift`
- `AccountingApp/Models/Category.swift`

### 2.2 流水
- 使用 SwiftData `@Query` 自动刷新（避免新增后列表不更新）
- 按天分组，按时间倒序

关键文件：
- `AccountingApp/Views/TransactionListView.swift`

### 2.3 报表
- 报表大 Tab：**支出 / 收入** 分开（避免页面过载）
- 支持：时间范围、币种筛选（或全部）
- 统计口径：在当前时间范围 & 当前类型（收入/支出 tab）下统计
- 多币种：分币种展示，不跨币种合计

关键文件：
- `AccountingApp/Views/ReportView.swift`

### 2.4 导出
- 导出 CSV
- 导出 Excel `.xls`（Excel 2003 XML Spreadsheet 格式）
- 文件名使用 `yyyy-MM-dd`（避免 locale 产生 `/` 导致写文件失败）
- 日期范围已做“当天起止”正规化，避免 endDate=00:00 漏数据

关键文件：
- `AccountingApp/Views/SettingsView.swift`（ExportView）

### 2.5 导入（迁移）
- 从文件导入（CSV/XLS）
- 支持导入本 App 导出的 CSV / `.xls`（Excel 2003 XML）
- 项目自动补齐：导入遇到不存在的项目名会自动创建
- 导入完成后保存 SwiftData，并触发刷新通知

实现位置（当前约束）：
- 导入逻辑**暂时放在** `AccountingApp/Utilities/Theme.swift` 末尾（带注释）
  - 原因：避免“新 Swift 文件没加入 Xcode target 导致导入代码没编译进 App”。

入口位置：
- `更多` → `导出` 页面下的 `导入` Section

## 3. 关键约定 / 口径
### 3.1 金额存储
- `Transaction.amountMinor` 使用“分”为单位（Int64）
- 展示/导出时换算回 Decimal

### 3.2 日期范围（报表/导出/导入解析）
- 查询时必须正规化：
  - `from = startOfDay(startDate)`
  - `to = endDate 当天 23:59:59`
- 导入解析时间：做多格式兼容（见 Theme.swift 的 DateParser）

### 3.3 分类结构
- 支出：`categoryL1=一级`，`categoryL2=二级`
- 收入：`categoryL1="收入"`，`categoryL2=收入分类`

## 4. 常见坑（已修复但别再踩）
1) SwiftData 变更后列表不刷新：列表用 `@Query` 最稳。
2) 报表/导出为空：`endDate` 常是 00:00，要做“当天起止”。
3) 导出失败：文件名不能包含 `/`，用 `yyyy-MM-dd`。
4) 分类 sheet 缓存：对 sheet 内容 `.id(type)` 强制重建。

## 5. 快速上手（回坑指南）
### 5.1 构建
```bash
xcodebuild -project AccountingApp.xcodeproj -scheme AccountingApp -sdk iphonesimulator -configuration Debug build
```

### 5.2 安装到模拟器并启动
```bash
DERIVED=/tmp/AccountingAppDerived
rm -rf "$DERIVED"
xcodebuild -project AccountingApp.xcodeproj -scheme AccountingApp -sdk iphonesimulator -configuration Debug -derivedDataPath "$DERIVED" build
APP=$(find "$DERIVED" -type d -name 'AccountingApp.app' -path '*Debug-iphonesimulator*' | head -n 1)

xcrun simctl uninstall booted com.shawn.AccountingApp || true
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.shawn.AccountingApp
```

> 如果提示 `No devices are booted.`：先启动 Simulator 或用 `xcrun simctl boot <deviceId>`。

## 6. 仓库与版本
- GitHub: https://github.com/Shawnzhu2051/AccountingApp
- Tag: `v1.0.0`

## 7. 下一步可选 TODO
- 导入去重（按 datetime+amount+currency+category+project 生成 hash）
- 导入预览（导入条数、将创建多少项目）
- iCloud 同步（SwiftData + CloudKit）
- 流水搜索/筛选
