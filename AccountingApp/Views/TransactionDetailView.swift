import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let transaction: Transaction
    
    @State private var amount: String = ""
    @State private var currency: Currency = .sgd
    @State private var type: TransactionType = .expense
    @State private var datetime: Date = Date()
    @State private var categoryL1: String = ""
    @State private var categoryL2: String = ""
    @State private var showCategoryPicker = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    
    var body: some View {
        Form {
            // 收支类型
            Section {
                Picker("类型", selection: $type) {
                    Text(TransactionType.expense.rawValue).tag(TransactionType.expense)
                    Text(TransactionType.income.rawValue).tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
            }
            
            // 金额
            Section("金额") {
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 36, weight: .bold))
            }
            
            // 币种
            Section("币种") {
                Picker("币种", selection: $currency) {
                    Text("SGD").tag(Currency.sgd)
                    Text("RMB").tag(Currency.rmb)
                    Text("USD").tag(Currency.usd)
                }
                .pickerStyle(.segmented)
            }
            
            // 分类
            Section("分类") {
                Button(action: {
                    showCategoryPicker = true
                }) {
                    HStack {
                        Text("选择分类")
                            .foregroundColor(.primary)
                        Spacer()
                        if !categoryL1.isEmpty && !categoryL2.isEmpty {
                            Text("\(categoryL1) - \(categoryL2)")
                                .foregroundColor(.secondary)
                        } else {
                            Text("必填")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            // 时间
            Section("时间") {
                DatePicker("时间", selection: $datetime)
            }
            
            // 项目
            Section("项目") {
                Text("默认项目")
                    .foregroundColor(.secondary)
            }
            
            // 删除按钮
            Section {
                Button(role: .destructive, action: {
                    showDeleteConfirm = true
                }) {
                    HStack {
                        Spacer()
                        Text("删除交易")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("编辑交易")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    updateTransaction()
                }
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView(
                selectedL1: $categoryL1,
                selectedL2: $categoryL2
            )
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteTransaction()
            }
        } message: {
            Text("确定要删除这笔交易吗？")
        }
        .alert("错误", isPresented: .constant(errorMessage != nil)) {
            Button("确定") {
                errorMessage = nil
            }
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
        .onAppear {
            loadTransaction()
        }
    }
    
    private func loadTransaction() {
        amount = String(describing: transaction.amount)
        currency = transaction.currency
        type = transaction.type
        datetime = transaction.datetime
        categoryL1 = transaction.categoryL1
        categoryL2 = transaction.categoryL2
    }
    
    private func updateTransaction() {
        // 验证
        guard !amount.isEmpty,
              let amountDecimal = Decimal(string: amount),
              !categoryL1.isEmpty,
              !categoryL2.isEmpty else {
            errorMessage = "请填写所有必填字段"
            return
        }
        
        let amountMinor = Int64(truncating: (amountDecimal * Decimal(100)) as NSNumber)
        
        // 更新
        transaction.amountMinor = amountMinor
        transaction.currency = currency
        transaction.type = type
        transaction.datetime = datetime
        transaction.categoryL1 = categoryL1
        transaction.categoryL2 = categoryL2
        transaction.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
    
    private func deleteTransaction() {
        modelContext.delete(transaction)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
}
