import Foundation
import SwiftData

@MainActor
class AddTransactionViewModel: ObservableObject {
    @Published var amount: String = ""
    @Published var currency: Currency = .sgd
    @Published var type: TransactionType = .expense
    @Published var datetime: Date = Date()
    @Published var selectedProjectId: UUID?
    @Published var categoryL1: String = ""
    @Published var categoryL2: String = ""
    @Published var errorMessage: String?
    
    private let repository: TransactionRepository
    private let projectRepository: ProjectRepository
    
    init(modelContext: ModelContext) {
        self.repository = TransactionRepository(modelContext: modelContext)
        self.projectRepository = ProjectRepository(modelContext: modelContext)
        
        // 设置默认项目
        loadDefaultProject()
    }
    
    func loadDefaultProject() {
        do {
            if let defaultProject = try projectRepository.fetchDefault() {
                selectedProjectId = defaultProject.id
            }
        } catch {
            errorMessage = "加载默认项目失败"
        }
    }
    
    func validate() -> Bool {
        guard !amount.isEmpty,
              let _ = Decimal(string: amount),
              selectedProjectId != nil,
              !categoryL1.isEmpty,
              !categoryL2.isEmpty else {
            errorMessage = "请填写所有必填字段"
            return false
        }
        return true
    }
    
    func save() -> Bool {
        guard validate() else { return false }
        
        guard let amountDecimal = Decimal(string: amount),
              let projectId = selectedProjectId else {
            errorMessage = "数据格式错误"
            return false
        }
        
        let amountMinor = Int64(truncating: (amountDecimal * Decimal(100)) as NSNumber)
        
        let transaction = Transaction(
            amountMinor: amountMinor,
            currency: currency,
            type: type,
            datetime: datetime,
            projectId: projectId,
            categoryL1: categoryL1,
            categoryL2: categoryL2
        )
        
        do {
            try repository.save(transaction)
            return true
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
            return false
        }
    }
    
    func reset() {
        amount = ""
        currency = .sgd
        type = .expense
        datetime = Date()
        categoryL1 = ""
        categoryL2 = ""
        loadDefaultProject()
    }
}
