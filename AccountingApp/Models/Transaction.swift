import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var amountMinor: Int64 // 存储最小货币单位(分/cent),避免浮点误差
    var currency: Currency
    var type: TransactionType
    var datetime: Date
    var projectId: UUID
    var categoryL1: String
    var categoryL2: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        amountMinor: Int64,
        currency: Currency,
        type: TransactionType,
        datetime: Date = Date(),
        projectId: UUID,
        categoryL1: String,
        categoryL2: String
    ) {
        self.id = id
        self.amountMinor = amountMinor
        self.currency = currency
        self.type = type
        self.datetime = datetime
        self.projectId = projectId
        self.categoryL1 = categoryL1
        self.categoryL2 = categoryL2
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // 金额转换为Decimal(显示用)
    var amount: Decimal {
        get {
            Decimal(amountMinor) / Decimal(100)
        }
        set {
            amountMinor = Int64(truncating: (newValue * Decimal(100)) as NSNumber)
        }
    }
}

enum Currency: String, Codable {
    case sgd = "SGD"
    case rmb = "RMB"
    case usd = "USD"
    
    var symbol: String {
        switch self {
        case .sgd: return "S$"
        case .rmb: return "¥"
        case .usd: return "$"
        }
    }
}

enum TransactionType: String, Codable {
    case expense = "支出"
    case income = "收入"
}
