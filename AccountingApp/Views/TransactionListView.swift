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

    private func defaultProjectId() -> UUID? {
        projects.first(where: { $0.isDefault })?.id ?? projects.first?.id
    }

    private func recentMonthKeys() -> Set<String> {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
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
            ZStack {
                // Unified background (single tone, dark-mode friendly)
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Project filter with Liquid Glass
                    if !projects.isEmpty {
                        projectFilter
                    }

                    if filteredTransactions.isEmpty {
                        emptyStateView
                    } else {
                        transactionList
                    }
                }
            }
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

    private var projectFilter: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.subheadline)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("暂无记录", systemImage: "tray.fill")
        } description: {
            Text("点击右下角 + 按钮添加第一笔交易")
        }
    }

    private var transactionList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedByMonth, id: \.0) { monthKey, monthDate, monthTransactions in
                    let isExpanded = expandedMonths.contains(monthKey)
                    let summary = monthSummary(monthTransactions)

                    VStack(spacing: 0) {
                        // Month header
                        monthHeader(
                            name: monthDisplayName(monthDate),
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

                        if isExpanded {
                            let days = dayGroups(for: monthTransactions)
                            VStack(spacing: 2) {
                                ForEach(days, id: \.0) { date, dayTransactions in
                                    // Day header
                                    HStack {
                                        Text(dayDisplayName(date))
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, 14)
                                    .padding(.bottom, 4)

                                    // Transaction rows
                                    VStack(spacing: 0) {
                                        ForEach(Array(dayTransactions.enumerated()), id: \.element.id) { index, transaction in
                                            NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                                TransactionRowView(transaction: transaction)
                                            }
                                            .buttonStyle(.plain)

                                            if index < dayTransactions.count - 1 {
                                                Divider()
                                                    .padding(.leading, 68)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .background(
                                        // Keep rows + container visually one tone; add subtle glass/material
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(.systemBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .strokeBorder(.separator.opacity(colorScheme == .dark ? 0.35 : 0.25), lineWidth: 0.5)
                                            )
                                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 100) // Space for FAB
        }
    }

    private func monthHeader(
        name: String,
        isExpanded: Bool,
        summary: (income: Decimal, expense: Decimal),
        count: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Text(name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // Compact summary — single line
                HStack(spacing: 8) {
                    if summary.expense > 0 {
                        Text("支\(summary.expense.formatted())")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                    }
                    if summary.income > 0 {
                        Text("收\(summary.income.formatted())")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
                .truncationMode(.tail)

                Text("\(count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    // avoid any accent-tinted feel; keep neutral
                    .background(Color(.systemFill).opacity(0.55))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            // keep Liquid Glass but prevent default blue accent highlight
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .tint(.primary)
        .padding(.horizontal, 16)
    }
}

// MARK: - Transaction Row (iOS 26 style)

struct TransactionRowView: View {
    let transaction: Transaction
    @Environment(\.colorScheme) private var colorScheme

    private var categoryColor: Color {
        CategoryIcons.color(for: transaction.categoryL1)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon — bigger + glassy, but still single-tone row
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(categoryColor.opacity(colorScheme == .dark ? 0.28 : 0.14))
                    .frame(width: 54, height: 54)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Image(systemName: CategoryIcons.icon(for: transaction.categoryL2))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(categoryColor)
            }

            // Text content (bigger)
            VStack(alignment: .leading, spacing: 6) {
                Text(transaction.categoryL2)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(transaction.note.isEmpty ? transaction.categoryL1 : transaction.note)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            // Amount (bigger, monospaced)
            Text("\(transaction.type == .expense ? "-" : "+")\(transaction.currency.symbol)\(transaction.amount.formatted())")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(transaction.type == .expense ? .red : .green)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

#Preview {
    TransactionListView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
