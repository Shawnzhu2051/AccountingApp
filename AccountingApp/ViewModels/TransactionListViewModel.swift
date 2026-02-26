import Foundation
import SwiftData

@MainActor
class TransactionListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: TransactionRepository
    
    init(modelContext: ModelContext) {
        self.repository = TransactionRepository(modelContext: modelContext)
    }
    
    func loadTransactions() {
        isLoading = true
        defer { isLoading = false }
        
        do {
            transactions = try repository.fetchAll()
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        do {
            try repository.delete(transaction)
            loadTransactions()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
    
    // 按日期分组
    func groupedByDate() -> [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.datetime)
        }
        return grouped.sorted { $0.key > $1.key }
    }
}
