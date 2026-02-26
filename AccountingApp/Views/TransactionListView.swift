import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TransactionListViewModel?
    
    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.isLoading {
                        ProgressView()
                    } else if vm.transactions.isEmpty {
                        ContentUnavailableView(
                            "暂无记录",
                            systemImage: "tray",
                            description: Text("点击+添加第一笔交易")
                        )
                    } else {
                        transactionList
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("流水")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel?.loadTransactions()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert("错误", isPresented: .constant(viewModel?.errorMessage != nil)) {
                Button("确定") {
                    viewModel?.errorMessage = nil
                }
            } message: {
                if let message = viewModel?.errorMessage {
                    Text(message)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = TransactionListViewModel(modelContext: modelContext)
                viewModel = vm
                vm.loadTransactions()
            }
        }
    }
    
    private var transactionList: some View {
        List {
            if let vm = viewModel {
                ForEach(vm.groupedByDate(), id: \.0) { date, transactions in
                    Section(header: Text(date.formatted(date: .long, time: .omitted))) {
                        ForEach(transactions) { transaction in
                            NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                TransactionRow(transaction: transaction)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                vm.deleteTransaction(transactions[index])
                            }
                        }
                    }
                }
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(transaction.categoryL2) · \(transaction.categoryL1)")
                    .font(.headline)
                
                HStack {
                    Text(transaction.datetime.formatted(date: .omitted, time: .shortened))
                    Text("·")
                    // TODO: 显示项目名称(需要关联查询)
                    Text("项目")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.currency.symbol)\(transaction.amount.formatted())")
                    .font(.title3)
                    .foregroundColor(transaction.type == .expense ? .red : .green)
                
                Text(transaction.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TransactionListView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
