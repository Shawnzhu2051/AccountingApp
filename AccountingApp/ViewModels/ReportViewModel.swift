import Foundation
import SwiftData

@MainActor
class ReportViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var selectedCurrency: Currency? = nil
    @Published var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @Published var endDate: Date = Date()
    @Published var errorMessage: String?
    
    private let repository: TransactionRepository
    
    init(modelContext: ModelContext) {
        self.repository = TransactionRepository(modelContext: modelContext)
    }
    
    func loadTransactions() {
        do {
            transactions = try repository.fetch(from: startDate, to: endDate)
            
            // 如果选择了币种,进一步过滤
            if let currency = selectedCurrency {
                transactions = transactions.filter { $0.currency == currency }
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }
    
    // 按分类统计(分币种)
    func groupByCategory() -> [Currency: [(String, Decimal)]] {
        var result: [Currency: [(String, Decimal)]] = [:]
        
        for currency in [Currency.sgd, .rmb, .usd] {
            let currencyTransactions = transactions.filter { $0.currency == currency }
            let grouped = Dictionary(grouping: currencyTransactions) { $0.categoryL1 }
            
            let stats = grouped.map { (category, txs) -> (String, Decimal) in
                let total = txs.reduce(Decimal(0)) { $0 + $1.amount }
                return (category, total)
            }.sorted { $0.1 > $1.1 }
            
            if !stats.isEmpty {
                result[currency] = stats
            }
        }
        
        return result
    }
    
    // 按项目统计(分币种)
    func groupByProject() -> [Currency: [(UUID, Decimal)]] {
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
    
    // 收支统计(分币种)
    func incomeExpenseStats() -> [Currency: (income: Decimal, expense: Decimal)] {
        var result: [Currency: (income: Decimal, expense: Decimal)] = [:]
        
        for currency in [Currency.sgd, .rmb, .usd] {
            let currencyTransactions = transactions.filter { $0.currency == currency }
            
            let income = currencyTransactions
                .filter { $0.type == .income }
                .reduce(Decimal(0)) { $0 + $1.amount }
            
            let expense = currencyTransactions
                .filter { $0.type == .expense }
                .reduce(Decimal(0)) { $0 + $1.amount }
            
            if income > 0 || expense > 0 {
                result[currency] = (income: income, expense: expense)
            }
        }
        
        return result
    }
}
