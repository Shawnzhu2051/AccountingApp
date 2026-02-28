import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
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

    private func defaultProjectId() -> UUID? {
        projects.first(where: { $0.isDefault })?.id ?? projects.first?.id
    }

    /// Determine which months should be expanded by default (recent 1 month)
    private func recentMonthKeys() -> Set<String> {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let currentKey = String(format: "%04d-%02d", comps.year!, comps.month!)
        return [currentKey]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Project filter - single picker
                if !projects.isEmpty {
                    HStack {
                        Text("项目")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("项目", selection: $selectedProjectId) {
                            Text("全部项目").tag(nil as UUID?)
                            ForEach(projects) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    Divider()
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
            // Re-expand recent month when switching projects
            if !initialized { return }
            expandedMonths = recentMonthKeys()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "tray.fill")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.3))
            VStack(spacing: 8) {
                Text("暂无记录")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("点击右下角 + 按钮添加第一笔交易")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            // Day header
                            Text(date.formatted(date: .long, time: .omitted))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .listRowBackground(Color(.systemGroupedBackground))
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))

                            ForEach(dayTransactions) { transaction in
                                NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                    TransactionRow(transaction: transaction)
                                }
                            }
                        }
                    }
                } header: {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if isExpanded {
                                expandedMonths.remove(monthKey)
                            } else {
                                expandedMonths.insert(monthKey)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16)

                            Text(monthDisplayName(monthDate))
                                .font(.callout.weight(.semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                if summary.expense > 0 {
                                    Text("支 \(summary.expense.formatted())")
                                        .font(.caption)
                                        .foregroundColor(.accentRed)
                                }
                                if summary.income > 0 {
                                    Text("收 \(summary.income.formatted())")
                                        .font(.caption)
                                        .foregroundColor(.accentGreen)
                                }
                            }

                            Text("\(monthTransactions.count)笔")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Transaction Row (original style, restored larger size)

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: CategoryIcons.icon(for: transaction.categoryL2))
                .font(.title3)
                .foregroundColor(categoryColor)
                .frame(width: 40, height: 40)
                .background(categoryColor.opacity(0.12))
                .cornerRadius(10)

            // Category + note
            VStack(alignment: .leading, spacing: 3) {
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

            // Amount + type badge
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(transaction.currency.symbol)\(transaction.amount.formatted())")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(transaction.type == .expense ? .accentRed : .accentGreen)

                Text(transaction.type.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(transaction.type == .expense ? Color.accentRed.opacity(0.1) : Color.accentGreen.opacity(0.1))
                    .foregroundColor(transaction.type == .expense ? .accentRed : .accentGreen)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        CategoryIcons.color(for: transaction.categoryL1)
    }
}

#Preview {
    TransactionListView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
