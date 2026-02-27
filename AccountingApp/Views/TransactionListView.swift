import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TransactionListViewModel?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.groupedBackground.ignoresSafeArea()
                
                Group {
                    if let vm = viewModel {
                        if vm.isLoading {
                            ProgressView()
                        } else if vm.transactions.isEmpty {
                            emptyStateView
                        } else {
                            transactionList
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
            .navigationTitle("流水")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel?.loadTransactions()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.accentBlue)
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
                if let vm = viewModel {
                    ForEach(vm.groupedByDate(), id: \.0) { date, transactions in
                        VStack(alignment: .leading, spacing: 12) {
                            // 日期标题
                            Text(date.formatted(date: .long, time: .omitted))
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            // 当天交易卡片
                            VStack(spacing: 8) {
                                ForEach(transactions) { transaction in
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
            }
            .padding(.vertical)
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // 分类图标
            categoryIcon
                .frame(width: 48, height: 48)
                .background(categoryColor.opacity(0.15))
                .cornerRadius(12)
            
            // 交易信息
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.categoryL2)
                    .font(.headline)
                
                HStack(spacing: 6) {
                    Text(transaction.categoryL1)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(transaction.datetime.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 金额
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
        Image(systemName: categoryIconName)
            .font(.title3)
            .foregroundColor(categoryColor)
    }
    
    private var categoryIconName: String {
        switch transaction.categoryL1 {
        case "娱乐": return "party.popper.fill"
        case "购物": return "cart.fill"
        case "日常": return "house.fill"
        case "出行": return "car.fill"
        case "人情": return "gift.fill"
        case "金融": return "chart.line.uptrend.xyaxis"
        case "医疗": return "cross.case.fill"
        case "住房": return "building.2.fill"
        default: return "circle.fill"
        }
    }
    
    private var categoryColor: Color {
        switch transaction.categoryL1 {
        case "娱乐": return .accentPurple
        case "购物": return .accentOrange
        case "日常": return .accentBlue
        case "出行": return .accentGreen
        case "人情": return Color(red: 1.0, green: 0.4, blue: 0.5)
        case "金融": return Color(red: 0.9, green: 0.7, blue: 0.3)
        case "医疗": return .accentRed
        case "住房": return Color(red: 0.5, green: 0.6, blue: 0.8)
        default: return .gray
        }
    }
}

#Preview {
    TransactionListView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
