import SwiftUI
import SwiftData

/// 分类交易详情页 - 点击饼图分类后跳转的落地页
struct CategoryTransactionsView: View {
    let category: String
    let categoryLevel: String
    let transactions: [Transaction]
    
    @Query(sort: [SortDescriptor(\.Project.name)])
    private var allProjects: [Project]
    
    private var projectNameMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: allProjects.map { ($0.id, $0.name) })
    }
    
    // 按天分组
    private var groupedByDate: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: transactions) { t in
            Calendar.current.startOfDay(for: t.datetime)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    // 总金额
    private var totalAmount: Decimal {
        transactions.reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    // 涉及的币种
    private var currencies: [Currency] {
        Array(Set(transactions.map { $0.currency })).sorted { $0.rawValue < $1.rawValue }
    }
    
    // 按币种统计
    private var amountByCurrency: [Currency: Decimal] {
        var result: [Currency: Decimal] = [:]
        for currency in currencies {
            result[currency] = transactions
                .filter { $0.currency == currency }
                .reduce(Decimal(0)) { $0 + $1.amount }
        }
        return result
    }
    
    var body: some View {
        List {
            // 统计摘要
            summarySection
            
            // 交易列表
            transactionsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - 统计摘要
    private var summarySection: some View {
        Section("统计摘要") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("交易笔数")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(transactions.count) 笔")
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("金额合计")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(currencies, id: \.self) { currency in
                        if let amount = amountByCurrency[currency] {
                            HStack {
                                Text(currency.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .leading)
                                
                                Spacer()
                                
                                Text("\(currency.symbol)\(amount.formatted())")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - 交易列表
    private var transactionsSection: some View {
        Group {
            if transactions.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("暂无交易记录")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
            } else {
                ForEach(groupedByDate, id: \.0) { date, dayTransactions in
                    Section {
                        ForEach(dayTransactions) { transaction in
                            TransactionDetailRow(
                                transaction: transaction,
                                projectName: projectNameMap[transaction.projectId] ?? "未知项目"
                            )
                        }
                    } header: {
                        Text(dateFormatted(date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func dateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            formatter.dateFormat = "yyyy年M月d日"
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.locale = Locale(identifier: "zh_CN")
            weekdayFormatter.dateFormat = "EEEE"
            return "\(formatter.string(from: date)) \(weekdayFormatter.string(from: date))"
        }
    }
}

// MARK: - 交易详情行
struct TransactionDetailRow: View {
    let transaction: Transaction
    let projectName: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 分类图标
            categoryIcon
            
            // 中间内容
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.categoryL2)
                    .font(.system(size: 16, weight: .medium))
                
                HStack(spacing: 4) {
                    Text(projectName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !transaction.note.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(transaction.note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Text(transaction.datetime.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 金额
            Text("\(transaction.currency.symbol)\(transaction.amount.formatted())")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(transaction.type == .expense ? .red : .green)
        }
        .padding(.vertical, 4)
    }
    
    private var categoryIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.15))
                .frame(width: 36, height: 36)
            
            Image(systemName: CategoryIcons.icon(for: transaction.categoryL2))
                .font(.system(size: 16))
                .foregroundColor(categoryColor)
        }
    }
    
    private var categoryColor: Color {
        CategoryIcons.color(for: transaction.categoryL1)
    }
}

#Preview {
    NavigationStack {
        CategoryTransactionsView(
            category: "日常",
            categoryLevel: "一级分类",
            transactions: []
        )
    }
    .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
