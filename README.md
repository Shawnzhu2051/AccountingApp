# AccountingApp - iOS记账应用

## 项目状态

🎉 **P0 MVP已完成** (2026-02-26)
- Phase 1-6: 全部完成
- QA验收: 进行中

### 已完成

#### 数据层
- ✅ SwiftData模型: Transaction, Project
- ✅ 分类字典: CategoryDictionary (8个一级分类,对应二级分类)
- ✅ Repository层: TransactionRepository, ProjectRepository

#### 业务逻辑层
- ✅ TransactionListViewModel (流水列表逻辑)
- ✅ AddTransactionViewModel (记账表单逻辑+验证)
- ✅ ProjectViewModel (项目管理逻辑)
- ✅ ReportViewModel (报表统计逻辑,支持分币种)

#### 视图层
- ✅ ContentView + MainTabView (Tab结构: 流水/报表/更多)
- ✅ TransactionListView (流水列表,按日分组)
- ✅ AddTransactionView (记账表单+分类双栏选择)
- ✅ ReportView (报表展示,分币种统计)
- ✅ SettingsView (项目管理+导出入口)

#### 核心功能
- ✅ 多币种支持 (SGD/RMB/USD)
- ✅ 分币种统计 (不跨币种合计)
- ✅ 二级分类选择
- ✅ 必填字段验证
- ✅ 金额存储(Int64,避免浮点误差)
- ✅ 默认项目初始化

### ✅ P0功能已完成

#### Phase 2-3: 完善记账和流水 ✅
- [x] 项目选择器 (使用默认项目)
- [x] 流水详情页 (编辑/删除)
- [x] 流水按日分组
- [x] ViewModel重构(直接使用State)

#### Phase 4: 项目管理 ✅
- [x] 项目删除迁移对话框
- [x] 项目编辑功能(重命名)
- [x] 设置默认项目

#### Phase 5: 报表增强 ✅
- [x] 时间范围选择器
- [x] 币种筛选
- [x] 维度切换 (分类/项目/时间/收支)
- [x] SwiftUI Charts集成
  - [x] 分类饼图
  - [x] 时间趋势折线图
  - [x] 收支对比柱状图
  - [x] 项目统计柱状图
- [x] **分币种不合计** (核心要求)

#### Phase 6: 导出功能 ✅
- [x] CSV导出(Excel完全兼容)
- [x] 时间段选择
- [x] 系统分享面板
- [x] 包含项目列

#### Phase 7: 整合测试 (进行中)
- [x] P0功能开发完成
- [ ] QA全流程验收
- [ ] Bug修复
- [ ] 性能优化

### 已知问题

~~1. **ViewModel初始化**: 当前ViewModel在init时创建临时ModelContext,需要改为通过Environment注入~~ ✅ 已解决(改用State)
~~2. **项目名称显示**: 流水列表中暂未显示项目名称(需要关联Project查询或使用@Relationship)~~ ⚠️ 待优化
~~3. **Xcode项目配置**: 需要创建.xcodeproj文件才能在Xcode中打开~~ ✅ 已解决(使用xcodegen)

**待QA验收的场景:**
1. 多币种报表分币种展示,无合计混淆
2. 项目删除迁移后历史交易projectId正确
3. 流水编辑后实时刷新
4. CSV导出格式正确且包含项目列

### 下一步

**当前阶段: QA验收**
1. 等待QA完整验收 (<@1476238523869958225>)
2. 根据验收结果修复Bug
3. 性能优化
4. 准备交付

**后续增强(非P0):**
- 流水中显示项目名称
- 项目选择器(支持自定义选择)
- 备注字段(可选)
- 更多图表样式

## 项目结构

```
AccountingApp/
├── Models/
│   ├── Transaction.swift       # 交易数据模型
│   ├── Project.swift            # 项目数据模型
│   └── Category.swift           # 分类字典
├── ViewModels/
│   ├── TransactionListViewModel.swift
│   ├── AddTransactionViewModel.swift
│   ├── ProjectViewModel.swift
│   └── ReportViewModel.swift
├── Views/
│   ├── ContentView.swift        # 主视图+Tab结构
│   ├── TransactionListView.swift
│   ├── AddTransactionView.swift
│   ├── ReportView.swift
│   └── SettingsView.swift
├── Repositories/
│   ├── TransactionRepository.swift
│   └── ProjectRepository.swift
└── AccountingAppApp.swift       # App入口
```

## 技术栈

- Swift + SwiftUI
- iOS 17+ (SwiftData)
- MVVM + Repository架构
- SwiftUI Charts (待集成)

## 构建说明

**当前状态**: 代码已完成,但需要创建Xcode项目文件才能编译运行。

下一步需要:
1. 在Xcode中创建新项目
2. 将现有代码文件添加到项目中
3. 配置Info.plist等
4. 运行测试

## PRD参考

详见Discord群聊 #ios记账软件开发群 中小朱1号OA的PRD/TRD文档。
