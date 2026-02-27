# AccountingApp – Skills / Dev Record（供后续继续开发）

> 目的：把本轮开发中沉淀的“做法、坑位、口径、操作命令”记录下来，方便之后继续迭代。
> 注意：这是项目内文档，不写入 OpenClaw memory。

## 项目背景与范围（MVP）

这是一个 iOS 记账 App：只做最基础但可用的功能闭环。

模块：
- 记账（新增流水）
- 流水（列表展示）
- 报表（Charts 展示统计）
- 导出（CSV + Excel .xls）
- 导入（从 CSV / .xls 迁移流水）

设计关键词：轻量、极客、用户友好；遵循 Apple HIG（颜色克制、信息层级清晰）。

## 技术栈与数据模型

- SwiftUI
- SwiftData（本地持久化）
- Charts（报表图表）

核心模型（简化描述）：
- `Transaction`
  - `amountMinor: Int64`（以分为单位）
  - `currency: Currency`（SGD/RMB/USD）
  - `type: TransactionType`（income/expense）
  - `datetime: Date`（目前选择器精确到“天”，但模型仍是 Date）
  - `projectId: UUID`
  - `categoryL1/categoryL2: String`
  - `note: String`
- `Project`
  - `id: UUID`
  - `name: String`
  - `isDefault: Bool`

### 分类字典约定
为兼容收入/支出不同层级：
- 支出：`categoryL1=一级`，`categoryL2=二级`
- 收入：`categoryL1="收入"`，`categoryL2=具体收入分类（工资/红包/奖金/其他）`

分类字典实现：`AccountingApp/Models/Category.swift`。

## 关键实现与踩坑记录

### 1) 流水页新增后不刷新（严重坑）
**现象**：新增交易后，流水页看不到。

**原因**：流水页最初用 ViewModel 手动 load，SwiftData 变更不会自动触发 ViewModel reload。

**解决**：流水页改为 SwiftData 原生查询：
- `TransactionListView` 使用 `@Query(sort: ...) var transactions`
- 让 SwiftData 负责自动刷新

这是“最稳的刷新策略”。

### 2) 报表/导出为空（日期边界坑）
**现象**：流水有数据，报表空 / 导出空。

**原因**：DatePicker 只选日期时，`endDate` 通常是当天 `00:00`；直接 `fetch(from:startDate,to:endDate)` 会把当天记录排除。

**解决**：查询范围正规化：
- `from = startOfDay(startDate)`
- `to = (startOfDay(endDate) + 1 day) - 1 second`

此逻辑在 ReportView / Export 中都应统一。

### 3) 导出失败（文件名包含 /）
**现象**：导出写文件失败。

**原因**：`Date.formatted(.numeric)` 在某些 locale 会产生 `2/27/2026`，`/` 不能出现在文件名。

**解决**：文件名使用安全格式：`yyyy-MM-dd`。

### 4) 分类 sheet 缓存导致“收入分类不显示”
**现象**：切换收入/支出后，分类 sheet 仍显示旧内容。

**解决**：对 sheet 内容加 `.id(type)`，强制按类型重建：
- `CategoryPickerView(...).id(type)`

### 5) 报表统计口径
已做：报表大 Tab 分为“支出/收入”，并且统计口径为：
- 在当前时间范围内
- 在当前币种筛选内（或全部币种分别展示）
- 在当前类型（收入/支出 tab）内

注意：**不跨币种合计**。

### 6) 导入（迁移）功能设计
目标：换手机/重装后，从旧导出文件恢复流水。

支持：
- CSV（本 App 导出的格式）
- XLS（Excel 2003 XML Spreadsheet；本 App 导出的 .xls）

策略：
- 逐行解析后插入 SwiftData
- 项目名不存在则自动创建
- 若没有默认项目，创建“日常项目”兜底
- 导入完成后 `modelContext.save()` 并发 `transactionsDidChange` 通知刷新（即使流水页已经用 @Query，也不坏）

实现位置：当前为了避免“新文件未加入 target 导致编译不进来”，导入逻辑暂时放在：
- `AccountingApp/Utilities/Theme.swift` 末尾（带注释说明）

后续建议：如果要更规范，把导入逻辑拆到独立文件并确保加入 Xcode target。

## UI 设计取向（AddTransactionView）

- 金额使用 `.primary`，收入/支出语义用 badge 表示（系统红/绿 + 低透明背景）
- 采用“极客卡片风”：将币种/分类/时间/项目聚合成一张多行卡片（带图标对齐 + Divider 缩进）

文件：`AccountingApp/Views/AddTransactionView.swift`。

## 构建/运行/安装常用命令（给 AI 或脚本用）

### Build
```bash
xcodebuild -project AccountingApp.xcodeproj -scheme AccountingApp -sdk iphonesimulator -configuration Debug build
```

### 安装到当前 booted 模拟器并启动
```bash
DERIVED=/tmp/AccountingAppDerived
rm -rf "$DERIVED"
xcodebuild -project AccountingApp.xcodeproj -scheme AccountingApp -sdk iphonesimulator -configuration Debug -derivedDataPath "$DERIVED" build
APP=$(find "$DERIVED" -type d -name 'AccountingApp.app' -path '*Debug-iphonesimulator*' | head -n 1)

xcrun simctl uninstall booted com.shawn.AccountingApp || true
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.shawn.AccountingApp
```

> 注意：如果提示 `No devices are booted.`，需要先启动模拟器（或指定具体 device id）。

## GitHub / 发布记录

- Repo: https://github.com/Shawnzhu2051/AccountingApp
- Tag: `v1.0.0`

## 后续迭代建议（可选）

- 导入去重（按 datetime+amount+currency+category+project 组合生成 hash，避免重复导入）
- 导入预览（展示将导入多少条/新建多少项目）
- iCloud 同步（SwiftData + CloudKit）
- 搜索/筛选流水
- 预算/提醒
