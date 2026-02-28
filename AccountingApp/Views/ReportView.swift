import SwiftUI
import SwiftData
import Charts

struct ReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Project.createdAt)])
    private var projects: [Project]

    @State private var transactions: [Transaction] = []
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var endDate = Date()
    @State private var selectedCurrency: Currency? = nil
    @State private var showDatePicker = false
    @State private var selectedProjectId: UUID?
    @State private var initialized = false

    @State private var reportType: TransactionType = .expense
    @State private var categoryLevel: CategoryLevel = .level1

    // Navigation state for category detail (fixes back-button bug)
    @State private var selectedCategoryDetail: CategoryDetailInfo?

    enum CategoryLevel {
        case level1, level2
    }

    struct CategoryDetailInfo: Hashable {
        let categoryName: String
        let currencyRaw: String
        let reportTypeRaw: String

        var currency: Currency { Currency(rawValue: currencyRaw)! }
        var transactionType: TransactionType { TransactionType(rawValue: reportTypeRaw)! }
    }

    private func defaultProjectId() -> UUID? {
        projects.first(where: { $0.isDefault })?.id ?? projects.first?.id
    }

    var body: some View {
        NavigationStack {
            List {
                typeTabSection
                dateRangeSection
                projectFilterSection
                currencyFilterSection
                summarySection
                categoryStatsSection
            }
            .navigationTitle("报表")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { loadTransactions() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .navigationDestination(item: $selectedCategoryDetail) { detail in
                CategoryDetailView(
                    categoryName: detail.categoryName,
                    currency: detail.currency,
                    transactions: filteredTransactionsForDetail(detail),
                    reportType: detail.transactionType
                )
            }
        }
        .onAppear {
            if !initialized {
                selectedProjectId = defaultProjectId()
                initialized = true
            }
            loadTransactions()
        }
    }

    // MARK: - Sections

    private var typeTabSection: some View {
        Section {
            Picker("类型", selection: $reportType) {
                Text("支出").tag(TransactionType.expense)
                Text("收入").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)
        }
        .onChange(of: reportType) { _, _ in loadTransactions() }
    }

    private var dateRangeSection: some View {
        Section {
            Button(action: { showDatePicker = true }) {
                HStack {
                    Text("时间范围")
                    Spacer()
                    Text("\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var projectFilterSection: some View {
        Section {
            Picker("项目", selection: $selectedProjectId) {
                Text("全部项目").tag(nil as UUID?)
                ForEach(projects) { project in
                    Text(project.name).tag(Optional(project.id))
                }
            }
        }
        .onChange(of: selectedProjectId) { _, _ in loadTransactions() }
    }

    private var currencyFilterSection: some View {
        Section {
            Picker("币种", selection: $selectedCurrency) {
                Text("全部").tag(nil as Currency?)
                Text("SGD").tag(Currency.sgd as Currency?)
                Text("RMB").tag(Currency.rmb as Currency?)
                Text("USD").tag(Currency.usd as Currency?)
            }
            .pickerStyle(.segmented)
        }
        .onChange(of: selectedCurrency) { _, _ in loadTransactions() }
    }

    private var summarySection: some View {
        Section(reportType == .expense ? "支出总览" : "收入总览") {
            ForEach(Array(totalByCurrency().keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { currency in
                if let total = totalByCurrency()[currency] {
                    HStack {
                        Text(currency.rawValue)
                            .font(.headline)
                        Spacer()
                        Text("\(currency.symbol)\(total.formatted())")
                            .font(.headline)
                            .foregroundColor(reportType == .expense ? .accentRed : .accentGreen)
                    }
                }
            }
        }
    }

    private var categoryStatsSection: some View {
        Group {
            Section {
                Picker("统计级别", selection: $categoryLevel) {
                    Text("一级分类").tag(CategoryLevel.level1)
                    Text("二级分类").tag(CategoryLevel.level2)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("分类统计")
            }

            Section {
                ForEach(Array(groupByCategory().keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { currency in
                    if let categories = groupByCategory()[currency] {
                        InteractivePieChart(
                            currency: currency,
                            categories: categories
                        )

                        // Category list — plain buttons, no NavigationLink (fixes double ">" bug)
                        CategoryListSection(
                            currency: currency,
                            categories: categories,
                            reportType: reportType,
                            categoryLevel: categoryLevel,
                            onSelect: { categoryName, cur in
                                selectedCategoryDetail = CategoryDetailInfo(
                                    categoryName: categoryName,
                                    currencyRaw: cur.rawValue,
                                    reportTypeRaw: reportType.rawValue
                                )
                            }
                        )
                    }
                }
            }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            Form {
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
            }
            .navigationTitle("选择时间范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        showDatePicker = false
                        loadTransactions()
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func loadTransactions() {
        let repo = TransactionRepository(modelContext: modelContext)
        do {
            let from = Calendar.current.startOfDay(for: startDate)
            let to = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
            let inclusiveEnd = to.addingTimeInterval(-1)

            var results = try repo.fetch(from: from, to: inclusiveEnd)
            results = results.filter { $0.type == reportType }

            if let projectId = selectedProjectId {
                results = results.filter { $0.projectId == projectId }
            }
            if let currency = selectedCurrency {
                results = results.filter { $0.currency == currency }
            }

            transactions = results
        } catch {
            print("加载失败: \(error)")
        }
    }

    private func groupByCategory() -> [Currency: [(String, Decimal)]] {
        var result: [Currency: [(String, Decimal)]] = [:]
        for currency in [Currency.sgd, .rmb, .usd] {
            let currencyTransactions = transactions.filter { $0.currency == currency }
            let stats: [(String, Decimal)]
            switch categoryLevel {
            case .level1:
                let grouped = Dictionary(grouping: currencyTransactions) { $0.categoryL1 }
                stats = grouped.map { (cat, txs) in (cat, txs.reduce(Decimal(0)) { $0 + $1.amount }) }.sorted { $0.1 > $1.1 }
            case .level2:
                let grouped = Dictionary(grouping: currencyTransactions) { $0.categoryL2 }
                stats = grouped.map { (cat, txs) in (cat, txs.reduce(Decimal(0)) { $0 + $1.amount }) }.sorted { $0.1 > $1.1 }
            }
            if !stats.isEmpty { result[currency] = stats }
        }
        return result
    }

    private func totalByCurrency() -> [Currency: Decimal] {
        var result: [Currency: Decimal] = [:]
        for currency in [Currency.sgd, .rmb, .usd] {
            let total = transactions.filter { $0.currency == currency }.reduce(Decimal(0)) { $0 + $1.amount }
            if total > 0 { result[currency] = total }
        }
        return result
    }

    private func filteredTransactionsForDetail(_ detail: CategoryDetailInfo) -> [Transaction] {
        transactions.filter { t in
            t.currency == detail.currency && {
                switch categoryLevel {
                case .level1: return t.categoryL1 == detail.categoryName
                case .level2: return t.categoryL2 == detail.categoryName
                }
            }()
        }
    }
}

// MARK: - Interactive Pie Chart (tap sector to show percentage)

struct InteractivePieChart: View {
    let currency: Currency
    let categories: [(String, Decimal)]

    @State private var selectedAngle: Double?
    @State private var highlightedCategory: String?

    private var total: Decimal {
        categories.reduce(Decimal(0)) { $0 + $1.1 }
    }

    private func percentage(for amount: Decimal) -> Double {
        guard total > 0 else { return 0 }
        return NSDecimalNumber(decimal: amount / total * 100).doubleValue
    }

    /// Find which category the selected angle falls into
    private func categoryForAngle(_ angle: Double) -> String? {
        var cumulative: Double = 0
        let totalDouble = NSDecimalNumber(decimal: total).doubleValue
        guard totalDouble > 0 else { return nil }
        for (category, amount) in categories {
            cumulative += NSDecimalNumber(decimal: amount).doubleValue / totalDouble
            if angle <= cumulative {
                return category
            }
        }
        return categories.last?.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(currency.rawValue)
                .font(.headline)

            ZStack {
                Chart(categories, id: \.0) { category, amount in
                    SectorMark(
                        angle: .value("金额", NSDecimalNumber(decimal: amount).doubleValue),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("分类", category))
                    .opacity(highlightedCategory == nil || highlightedCategory == category ? 1.0 : 0.35)
                }
                .chartAngleSelection(value: $selectedAngle)
                .frame(height: 220)

                // Center overlay when highlighted
                if let highlighted = highlightedCategory,
                   let item = categories.first(where: { $0.0 == highlighted }) {
                    VStack(spacing: 2) {
                        Text(highlighted)
                            .font(.caption.weight(.semibold))
                        Text(String(format: "%.1f%%", percentage(for: item.1)))
                            .font(.title3.weight(.bold))
                        Text("\(currency.symbol)\(item.1.formatted())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            .onChange(of: selectedAngle) { _, newAngle in
                withAnimation(.easeInOut(duration: 0.15)) {
                    if let angle = newAngle {
                        let totalDouble = NSDecimalNumber(decimal: total).doubleValue
                        guard totalDouble > 0 else { return }
                        highlightedCategory = categoryForAngle(angle / totalDouble)
                    } else {
                        highlightedCategory = nil
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Category List Section (uses plain buttons, not NavigationLink)

struct CategoryListSection: View {
    let currency: Currency
    let categories: [(String, Decimal)]
    let reportType: TransactionType
    let categoryLevel: ReportView.CategoryLevel
    let onSelect: (String, Currency) -> Void

    private var total: Decimal {
        categories.reduce(Decimal(0)) { $0 + $1.1 }
    }

    private func percentage(for amount: Decimal) -> Double {
        guard total > 0 else { return 0 }
        return NSDecimalNumber(decimal: amount / total * 100).doubleValue
    }

    var body: some View {
        ForEach(categories, id: \.0) { category, amount in
            Button {
                onSelect(category, currency)
            } label: {
                HStack {
                    Text(category)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "%.1f%%", percentage(for: amount)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(currency.symbol)\(amount.formatted())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
        }
    }
}

// MARK: - Category Detail View

struct CategoryDetailView: View {
    let categoryName: String
    let currency: Currency
    let transactions: [Transaction]
    let reportType: TransactionType

    private var total: Decimal {
        transactions.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var groupedByDate: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: transactions) { t in
            Calendar.current.startOfDay(for: t.datetime)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("总计")
                        .font(.headline)
                    Spacer()
                    Text("\(currency.symbol)\(total.formatted())")
                        .font(.headline)
                        .foregroundColor(reportType == .expense ? .accentRed : .accentGreen)
                }
                Text("\(transactions.count) 笔交易")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ForEach(groupedByDate, id: \.0) { date, dayTransactions in
                Section(date.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach(dayTransactions) { transaction in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.categoryL2)
                                    .font(.body.weight(.medium))
                                if !transaction.note.isEmpty {
                                    Text(transaction.note)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Text("\(currency.symbol)\(transaction.amount.formatted())")
                                .font(.body)
                                .monospacedDigit()
                                .foregroundColor(reportType == .expense ? .accentRed : .accentGreen)
                        }
                    }
                }
            }
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Legacy Charts (kept for compatibility)

struct IncomeExpenseChart: View {
    let currency: Currency
    let stats: (income: Decimal, expense: Decimal)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currency.rawValue).font(.headline)
            Chart {
                BarMark(x: .value("类型", "收入"), y: .value("金额", NSDecimalNumber(decimal: stats.income).doubleValue))
                    .foregroundStyle(Color.accentGreen).cornerRadius(8)
                BarMark(x: .value("类型", "支出"), y: .value("金额", NSDecimalNumber(decimal: stats.expense).doubleValue))
                    .foregroundStyle(Color.accentRed).cornerRadius(8)
            }
            .frame(height: 200)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ReportView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
