import Foundation
import SwiftData

@MainActor
class TransactionRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // 获取所有交易(按时间倒序)
    func fetchAll() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.datetime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    // 按时间范围获取
    func fetch(from startDate: Date, to endDate: Date) throws -> [Transaction] {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.datetime >= startDate && transaction.datetime <= endDate
        }
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.datetime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    // 按币种获取
    func fetch(currency: Currency) throws -> [Transaction] {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.currency == currency
        }
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.datetime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    // 保存
    func save(_ transaction: Transaction) throws {
        modelContext.insert(transaction)
        try modelContext.save()
    }
    
    // 更新
    func update(_ transaction: Transaction) throws {
        transaction.updatedAt = Date()
        try modelContext.save()
    }
    
    // 删除
    func delete(_ transaction: Transaction) throws {
        modelContext.delete(transaction)
        try modelContext.save()
    }
    
    // 按项目ID更新
    func updateProject(from oldProjectId: UUID, to newProjectId: UUID) throws {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.projectId == oldProjectId
        }
        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        let transactions = try modelContext.fetch(descriptor)
        
        for transaction in transactions {
            transaction.projectId = newProjectId
            transaction.updatedAt = Date()
        }
        try modelContext.save()
    }
}
