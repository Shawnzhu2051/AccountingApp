import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: [SortDescriptor(\Transaction.datetime, order: .reverse)])
    private var allTransactions: [Transaction]
    @Query(sort: [SortDescriptor(\Project.createdAt)])
    private var projects: [Project]

    @State private var selectedProjectId: UUID?
    @State private var expandedMonths: Set<String> = []
    @State private var initialized = false

    private var filteredTransactions: [Transaction] {
        guard let projectId = selectedProjectId else { return allTransactions }
        return allTransactions.filter { $0.projectId == projectId }
    }

    private var groupedByMonth: [(String, Date, [Transaction])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { t -> String in
            let comps = cal.dateComponents([.year, .month], from: t.datetime)
            return String(format: "%04d-%02d", comps.year!, comps.month!)
        }
        return grouped
            .map { key, txs -> (String, Date, [Transaction]) in
                let sorted = txs.sorted { $0.datetime > $1.datetime }
                return (key, sorted.first!.datetime, sorted)
            }
            .sorted { $0.0 > $1.0 }
    }

    private func dayGroups(for transactions: [Transaction]) -> [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: transactions) { t in
            Calendar.current.startOfDay(for: t.datetime)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func monthDisplayName(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月"
        return fmt.string(from: date)
    }

    private func monthSummary(_ transactions: [Transaction]) -> (income: Decimal, expense: Decimal) {
        let income = transactions.filter { $0.type == .income }.reduce(Decimal(0)) { $0 + $1.amount }
        let expense = transactions.filter { $0.type == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
        return (income, expense)
    }

    private func daySummary(_ transactions: [Transaction]) -> (income: Decimal, expense: Decimal) {
        let income = transactions.filter { $0.type == .income }.reduce(Decimal(0)) { $0 + $1.amount }
        let expense = transactions.filter { $0.type == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
        return (income, expense)
    }

    private func defaultProjectId() -> UUID? {
        projects.first(where: { $0.isDefault })?.id ?? projects.first?.id
    }

    private func recentMonthKeys() -> Set<String> {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        return [String(format: "%04d-%02d", comps.year!, comps.month!)]
    }

    private func dayDisplayName(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 EEEE"
        return fmt.string(from: date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Project filter
                if !projects.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Picker("项目", selection: $selectedProjectId) {
                            Text("全部项目").tag(nil as UUID?)
                            ForEach(projects) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                }

                if filteredTransactions.isEmpty {
                    emptyStateView
                } else {
                    transactionList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("流水")
        }
        .onAppear {
            if !initialized {
                selectedProjectId = defaultProjectId()
                expandedMonths = recentMonthKeys()
                initialized = true
            }
        }
        .onChange(of: selectedProjectId) { _, _ in
            if initialized { expandedMonths = recentMonthKeys() }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("暂无记录", systemImage: "tray.fill")
        } description: {
            Text("点击右下角 + 按钮添加第一笔交易")
        }
    }

    private var transactionList: some View {
        List {
            ForEach(groupedByMonth, id: \.0) { monthKey, monthDate, monthTransactions in
                let isExpanded = expandedMonths.contains(monthKey)
                let summary = monthSummary(monthTransactions)

                Section {
                    if isExpanded {
                        let days = dayGroups(for: monthTransactions)
                        ForEach(days, id: \.0) { date, dayTransactions in
                            let daySummaryData = daySummary(dayTransactions)

                            // Day header row
                            HStack {
                                Text(dayDisplayName(date))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if daySummaryData.expense > 0 {
                                    Text("-\(daySummaryData.expense.formatted())")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .listRowBackground(Color(.systemGroupedBackground))
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))
                            .listRowSeparator(.hidden)

                            ForEach(dayTransactions) { transaction in
                                NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                    TransactionRowView(transaction: transaction)
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            }
                        }
                    }
                } header: {
                    MonthHeaderView(
                        monthName: monthDisplayName(monthDate),
                        isExpanded: isExpanded,
                        summary: summary,
                        count: monthTransactions.count
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if isExpanded {
                                expandedMonths.remove(monthKey)
                            } else {
                                expandedMonths.insert(monthKey)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Month Header

private struct MonthHeaderView: View {
    let monthName: String
    let isExpanded: Bool
    let summary: (income: Decimal, expense: Decimal)
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Text(monthName)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 12) {
                    if summary.expense > 0 {
                        Label {
                            Text(summary.expense.formatted())
                                .font(.caption.weight(.medium))
                        } icon: {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2)
                        }
                        .foregroundStyle(.red)
                    }
                    if summary.income > 0 {
                        Label {
                            Text(summary.income.formatted())
                                .font(.caption.weight(.medium))
                        } icon: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.caption2)
                        }
                        .foregroundStyle(.green)
                    }
                }

                Text("\(count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Transaction Row (iOS native style, dark mode compatible)

struct TransactionRowView: View {
    let transaction: Transaction
    @Environment(\.colorScheme) private var colorScheme

    private var categoryColor: Color {
        CategoryIcons.color(for: transaction.categoryL1)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon with adaptive background
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(categoryColor.opacity(colorScheme == .dark ? 0.25 : 0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: CategoryIcons.icon(for: transaction.categoryL2))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(categoryColor)
            }

            // Category info
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.categoryL2)
                    .font(.body)
                    .foregroundStyle(.primary)

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(transaction.categoryL1)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(transaction.type == .expense ? "-" : "+")\(transaction.currency.symbol)\(transaction.amount.formatted())")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(transaction.type == .expense ? .red : .green)

                Text(transaction.type.rawValue)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(transaction.type == .expense ? .red : .green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        (transaction.type == .expense ? Color.red : Color.green)
                            .opacity(colorScheme == .dark ? 0.2 : 0.1)
                    )
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    TransactionListView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
