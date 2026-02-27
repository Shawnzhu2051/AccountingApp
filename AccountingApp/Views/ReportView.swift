import SwiftUI
import SwiftData
import Charts

struct ReportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var transactions: [Transaction] = []
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var endDate = Date()
    @State private var selectedCurrency: Currency? = nil
    @State private var showDatePicker = false

    /// 报表大Tab：收入/支出
    @State private var reportType: TransactionType = .expense

    @State private var categoryLevel: CategoryLevel = .level1

    enum CategoryLevel {
        case level1, level2
    }

    var body: some View {
        NavigationStack {
            List {
                typeTabSection
                dateRangeSection
                currencyFilterSection
                summarySection
                categoryStatsSection
                timeTrendSection
                projectStatsSection
            }
            .navigationTitle("报表")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
        }
        .onAppear {
            loadTransactions()
        }
    }
    
    private var refreshButton: some View {
        Button(action: {
            loadTransactions()
        }) {
            Image(systemName: "arrow.clockwise")
        }
    }

    private var typeTabSection: some View {
        Section {
            Picker("类型", selection: $reportType) {
                Text("支出").tag(TransactionType.expense)
                Text("收入").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)
        }
        .onChange(of: reportType) { _, _ in
            loadTransactions()
        }
    }
    
    private var dateRangeSection: some View {
        Section {
            Button(action: {
                showDatePicker = true
            }) {
                HStack {
                    Text("时间范围")
                    Spacer()
                    Text("\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundColor(.secondary)
                }
            }
        }
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
        .onChange(of: selectedCurrency) { _, _ in
            loadTransactions()
        }
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
                        CategoryPieChart(currency: currency, categories: categories)
                    }
                }
            }
        }
    }
    
    private var timeTrendSection: some View {
        Section("时间趋势") {
            ForEach(Array(groupByDate().keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { currency in
                if let dailyData = groupByDate()[currency] {
                    TimeTrendChart(currency: currency, dailyData: dailyData)
                }
            }
        }
    }
    
    private var projectStatsSection: some View {
        Section("项目统计") {
            ForEach(Array(groupByProject().keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { currency in
                if let projects = groupByProject()[currency] {
                    ProjectBarChart(currency: currency, projects: projects, modelContext: modelContext)
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
    
    private func loadTransactions() {
        let repo = TransactionRepository(modelContext: modelContext)
        do {
            // 关键：把选择的日期范围正规化到“当天起止”，否则会出现：
            // - startDate 带时间(默认现在)导致当天早上的记录被排除
            // - endDate 若是 .date 选择器拿到的是 00:00，导致当天的记录被排除
            let from = Calendar.current.startOfDay(for: startDate)
            let to = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
            let inclusiveEnd = to.addingTimeInterval(-1)

            var results = try repo.fetch(from: from, to: inclusiveEnd)

            // 报表大Tab：收入/支出分开
            results = results.filter { $0.type == reportType }

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
                stats = grouped.map { (category, txs) -> (String, Decimal) in
                    let total = txs.reduce(Decimal(0)) { $0 + $1.amount }
                    return (category, total)
                }.sorted { $0.1 > $1.1 }
                
            case .level2:
                let grouped = Dictionary(grouping: currencyTransactions) { $0.categoryL2 }
                stats = grouped.map { (category, txs) -> (String, Decimal) in
                    let total = txs.reduce(Decimal(0)) { $0 + $1.amount }
                    return (category, total)
                }.sorted { $0.1 > $1.1 }
            }
            
            if !stats.isEmpty {
                result[currency] = stats
            }
        }
        
        return result
    }
    
    private func totalByCurrency() -> [Currency: Decimal] {
        var result: [Currency: Decimal] = [:]

        for currency in [Currency.sgd, .rmb, .usd] {
            let currencyTransactions = transactions.filter { $0.currency == currency }
            let total = currencyTransactions.reduce(Decimal(0)) { $0 + $1.amount }
            if total > 0 {
                result[currency] = total
            }
        }

        return result
    }
    
    private func groupByDate() -> [Currency: [(Date, Decimal)]] {
        var result: [Currency: [(Date, Decimal)]] = [:]
        
        for currency in [Currency.sgd, .rmb, .usd] {
            let currencyTransactions = transactions.filter { $0.currency == currency }
            let grouped = Dictionary(grouping: currencyTransactions) { transaction in
                Calendar.current.startOfDay(for: transaction.datetime)
            }
            
            let stats = grouped.map { (date, txs) -> (Date, Decimal) in
                let total = txs.reduce(Decimal(0)) { $0 + $1.amount }
                return (date, total)
            }.sorted { $0.0 < $1.0 }
            
            if !stats.isEmpty {
                result[currency] = stats
            }
        }
        
        return result
    }
    
    private func groupByProject() -> [Currency: [(UUID, Decimal)]] {
        var result: [Currency: [(UUID, Decimal)]] = [:]
        
        for currency in [Currency.sgd, .rmb, .usd] {
            let currencyTransactions = transactions.filter { $0.currency == currency }
            let grouped = Dictionary(grouping: currencyTransactions) { $0.projectId }
            
            let stats = grouped.map { (projectId, txs) -> (UUID, Decimal) in
                let total = txs.reduce(Decimal(0)) { $0 + $1.amount }
                return (projectId, total)
            }.sorted { $0.1 > $1.1 }
            
            if !stats.isEmpty {
                result[currency] = stats
            }
        }
        
        return result
    }
}

// MARK: - Chart Components

struct IncomeExpenseChart: View {
    let currency: Currency
    let stats: (income: Decimal, expense: Decimal)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currency.rawValue)
                .font(.headline)
            
            Chart {
                BarMark(
                    x: .value("类型", "收入"),
                    y: .value("金额", NSDecimalNumber(decimal: stats.income).doubleValue)
                )
                .foregroundStyle(Color.accentGreen)
                .cornerRadius(8)
                
                BarMark(
                    x: .value("类型", "支出"),
                    y: .value("金额", NSDecimalNumber(decimal: stats.expense).doubleValue)
                )
                .foregroundStyle(Color.accentRed)
                .cornerRadius(8)
            }
            .frame(height: 200)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("收入")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(currency.symbol)\(stats.income.formatted())")
                        .font(.smallAmount)
                        .foregroundColor(.accentGreen)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("支出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(currency.symbol)\(stats.expense.formatted())")
                        .font(.smallAmount)
                        .foregroundColor(.accentRed)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct CategoryPieChart: View {
    let currency: Currency
    let categories: [(String, Decimal)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currency.rawValue)
                .font(.headline)
            
            Chart(categories, id: \.0) { category, amount in
                SectorMark(
                    angle: .value("金额", NSDecimalNumber(decimal: amount).doubleValue),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("分类", category))
            }
            .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(categories, id: \.0) { category, amount in
                    HStack {
                        Text(category)
                            .font(.caption)
                        Spacer()
                        Text("\(currency.symbol)\(amount.formatted())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct TimeTrendChart: View {
    let currency: Currency
    let dailyData: [(Date, Decimal)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currency.rawValue)
                .font(.headline)
            
            Chart {
                ForEach(dailyData, id: \.0) { date, amount in
                    LineMark(
                        x: .value("日期", date),
                        y: .value("金额", NSDecimalNumber(decimal: amount).doubleValue)
                    )
                    .foregroundStyle(Color.accentBlue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 200)
        }
        .padding(.vertical, 8)
    }
}

struct ProjectBarChart: View {
    let currency: Currency
    let projects: [(UUID, Decimal)]
    let modelContext: ModelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currency.rawValue)
                .font(.headline)
            
            Chart(projects, id: \.0) { projectId, amount in
                BarMark(
                    x: .value("项目", projectNameById(projectId)),
                    y: .value("金额", NSDecimalNumber(decimal: amount).doubleValue)
                )
                .foregroundStyle(Color.accentBlue)
            }
            .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(projects, id: \.0) { projectId, amount in
                    HStack {
                        Text(projectNameById(projectId))
                            .font(.caption)
                        Spacer()
                        Text("\(currency.symbol)\(amount.formatted())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func projectNameById(_ id: UUID) -> String {
        let repo = ProjectRepository(modelContext: modelContext)
        if let projects = try? repo.fetchAll(),
           let project = projects.first(where: { $0.id == id }) {
            return project.name
        }
        return "未知项目"
    }
}

#Preview {
    ReportView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
