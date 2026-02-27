import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount: String = ""
    @State private var currency: Currency = .sgd
    @State private var type: TransactionType = .expense
    @State private var datetime: Date = Date()
    @State private var categoryL1: String = ""
    @State private var categoryL2: String = ""
    @State private var showCategoryPicker = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.groupedBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 收支类型
                        Picker("类型", selection: $type) {
                            Text(TransactionType.expense.rawValue).tag(TransactionType.expense)
                            Text(TransactionType.income.rawValue).tag(TransactionType.income)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        // 金额输入
                        VStack(spacing: 8) {
                            Text("金额")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack {
                                Text(currency.symbol)
                                    .font(.currencyAmount)
                                    .foregroundColor(.secondary)
                                
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .font(.currencyAmount)
                                    .foregroundColor(type == .expense ? .accentRed : .accentGreen)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .sectionCardStyle()
                        .padding(.horizontal)
                
                        // 币种选择
                        VStack(spacing: 8) {
                            Text("币种")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Picker("币种", selection: $currency) {
                                Text("SGD").tag(Currency.sgd)
                                Text("RMB").tag(Currency.rmb)
                                Text("USD").tag(Currency.usd)
                            }
                            .pickerStyle(.segmented)
                        }
                        .sectionCardStyle()
                        .padding(.horizontal)
                        
                        // 分类选择
                        Button(action: {
                            showCategoryPicker = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "tag.fill")
                                    .font(.title3)
                                    .foregroundColor(.accentBlue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("分类")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if !categoryL1.isEmpty && !categoryL2.isEmpty {
                                        Text("\(categoryL2) · \(categoryL1)")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("请选择分类")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .sectionCardStyle()
                        }
                        .padding(.horizontal)
                        
                        // 时间选择
                        VStack(spacing: 8) {
                            Text("时间")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            DatePicker("", selection: $datetime)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        .sectionCardStyle()
                        .padding(.horizontal)
                        
                        // 项目显示
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .font(.title3)
                                .foregroundColor(.accentOrange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("项目")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("默认项目")
                                    .font(.headline)
                            }
                            
                            Spacer()
                        }
                        .sectionCardStyle()
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveTransaction()
                    }
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerView(
                    selectedL1: $categoryL1,
                    selectedL2: $categoryL2
                )
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
        }
    }
    
    private func saveTransaction() {
        // 验证
        guard !amount.isEmpty,
              let amountDecimal = Decimal(string: amount),
              !categoryL1.isEmpty,
              !categoryL2.isEmpty else {
            errorMessage = "请填写所有必填字段"
            return
        }
        
        // 获取默认项目
        let projectRepo = ProjectRepository(modelContext: modelContext)
        guard let defaultProject = try? projectRepo.fetchDefault() else {
            errorMessage = "未找到默认项目"
            return
        }
        
        let amountMinor = Int64(truncating: (amountDecimal * Decimal(100)) as NSNumber)
        
        let transaction = Transaction(
            amountMinor: amountMinor,
            currency: currency,
            type: type,
            datetime: datetime,
            projectId: defaultProject.id,
            categoryL1: categoryL1,
            categoryL2: categoryL2
        )
        
        do {
            let repo = TransactionRepository(modelContext: modelContext)
            try repo.save(transaction)
            dismiss()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
}

struct CategoryPickerView: View {
    @Binding var selectedL1: String
    @Binding var selectedL2: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempL1: String = ""
    @State private var tempL2: String = ""
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // 一级分类
                List(CategoryDictionary.level1List, id: \.self) { level1 in
                    Button(action: {
                        tempL1 = level1
                    }) {
                        HStack {
                            Text(level1)
                            Spacer()
                            if level1 == tempL1 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // 二级分类
                List(CategoryDictionary.level2List(for: tempL1), id: \.self) { level2 in
                    Button(action: {
                        tempL2 = level2
                        selectedL1 = tempL1
                        selectedL2 = tempL2
                        dismiss()
                    }) {
                        HStack {
                            Text(level2)
                            Spacer()
                            if level2 == tempL2 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("选择分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if !selectedL1.isEmpty {
                tempL1 = selectedL1
            } else if let first = CategoryDictionary.level1List.first {
                tempL1 = first
            }
            tempL2 = selectedL2
        }
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
