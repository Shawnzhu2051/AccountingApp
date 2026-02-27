import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Query(sort: [SortDescriptor(\Transaction.datetime, order: .reverse)])
    private var transactions: [Transaction]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.groupedBackground.ignoresSafeArea()

                if transactions.isEmpty {
                    emptyStateView
                } else {
                    transactionList
                }
            }
            .navigationTitle("流水")
        }
    }

    private var groupedByDate: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: transactions) { t in
            Calendar.current.startOfDay(for: t.datetime)
        }
        return grouped.sorted { $0.key > $1.key }
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
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(groupedByDate, id: \.0) { date, dayTransactions in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(date.formatted(date: .long, time: .omitted))
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            ForEach(dayTransactions) { transaction in
                                NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                    TransactionRow(transaction: transaction)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            categoryIcon
                .frame(width: 48, height: 48)
                .background(categoryColor.opacity(0.15))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.categoryL2)
                    .font(.headline)

                Text(transaction.categoryL1)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.currency.symbol)\(transaction.amount.formatted())")
                    .font(.smallAmount)
                    .foregroundColor(transaction.type == .expense ? .accentRed : .accentGreen)

                Text(transaction.type.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(transaction.type == .expense ? Color.accentRed.opacity(0.1) : Color.accentGreen.opacity(0.1))
                    .foregroundColor(transaction.type == .expense ? .accentRed : .accentGreen)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var categoryIcon: some View {
        Image(systemName: CategoryIcons.icon(for: transaction.categoryL2))
            .font(.title3)
            .foregroundColor(categoryColor)
    }

    private var categoryColor: Color {
        CategoryIcons.color(for: transaction.categoryL1)
    }
}

#Preview {
    TransactionListView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
