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

    /// Group by month key "yyyy-MM", then by day within each month
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Project filter
                if !projects.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(projects) { project in
                                Button {
                                    selectedProjectId = project.id
                                } label: {
                                    Text(project.name)
                                        .font(.subheadline)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(selectedProjectId == project.id ? Color.accentBlue : Color(.systemGray5))
                                        .foregroundColor(selectedProjectId == project.id ? .white : .primary)
                                        .cornerRadius(18)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
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
                // Default: expand most recent month
                if let first = groupedByMonth.first {
                    expandedMonths.insert(first.0)
                }
                initialized = true
            }
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
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .listRowBackground(Color(.systemGroupedBackground))
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))

                            ForEach(dayTransactions) { transaction in
                                NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                    CompactTransactionRow(transaction: transaction)
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
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 16)

                            Text(monthDisplayName(monthDate))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 1) {
                                if summary.expense > 0 {
                                    Text("支 \(summary.expense.formatted())")
                                        .font(.caption2)
                                        .foregroundColor(.accentRed)
                                }
                                if summary.income > 0 {
                                    Text("收 \(summary.income.formatted())")
                                        .font(.caption2)
                                        .foregroundColor(.accentGreen)
                                }
                            }

                            Text("\(monthTransactions.count)笔")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Compact Transaction Row

struct CompactTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 10) {
            // Category icon
            Image(systemName: CategoryIcons.icon(for: transaction.categoryL2))
                .font(.body)
                .foregroundColor(CategoryIcons.color(for: transaction.categoryL1))
                .frame(width: 32, height: 32)
                .background(CategoryIcons.color(for: transaction.categoryL1).opacity(0.12))
                .cornerRadius(8)

            // Category + note
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.categoryL2)
                    .font(.subheadline.weight(.medium))
                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount
            Text("\(transaction.type == .expense ? "-" : "+")\(transaction.currency.symbol)\(transaction.amount.formatted())")
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundColor(transaction.type == .expense ? .accentRed : .accentGreen)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    TransactionListView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
