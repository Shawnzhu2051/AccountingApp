import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var amount: String = ""
    @State private var currency: Currency = .sgd
    @State private var type: TransactionType = .expense
    @State private var datetime: Date = Date()

    // 为兼容收入分类(单层)：
    // - 支出: categoryL1=一级分类, categoryL2=二级分类
    // - 收入: categoryL1="收入", categoryL2=收入分类(工资收入等)
    @State private var categoryL1: String = ""
    @State private var categoryL2: String = ""

    @State private var note: String = ""
    @State private var showCategoryPicker = false
    @State private var errorMessage: String?

    @State private var projects: [Project] = []
    @State private var selectedProjectId: UUID?
    @State private var defaultProjectName: String = "日常项目"

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
                        .onChange(of: type) { _, newValue in
                            // 切换收支时，清空分类避免脏数据
                            categoryL1 = ""
                            categoryL2 = ""

                            // 收入默认给一个更合理的初始值(仍然要求用户确认可改)
                            if newValue == .income, let first = CategoryDictionary.incomeCategories.first {
                                categoryL1 = "收入"
                                categoryL2 = first
                            }
                        }

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
                                        // 支出：二级 · 一级；收入：收入分类
                                        if type == .expense {
                                            Text("\(categoryL2) · \(categoryL1)")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                        } else {
                                            Text(categoryL2)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                        }
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

                        // 时间选择（默认现在，精确到天）
                        VStack(spacing: 8) {
                            Text("时间")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            DatePicker("", selection: $datetime, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        .sectionCardStyle()
                        .padding(.horizontal)

                        // 项目选择（默认日常项目）
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .font(.title3)
                                    .foregroundColor(.accentOrange)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("项目")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text(defaultProjectName)
                                        .font(.headline)
                                }

                                Spacer()
                            }

                            if !projects.isEmpty {
                                Picker("项目", selection: $selectedProjectId) {
                                    ForEach(projects) { project in
                                        Text(project.name).tag(Optional(project.id))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .sectionCardStyle()
                        .padding(.horizontal)

                        // 备注输入（可选）
                        VStack(spacing: 8) {
                            Text("备注（可选）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            TextField("添加备注...", text: $note, axis: .vertical)
                                .lineLimit(3...5)
                                .textFieldStyle(.roundedBorder)
                        }
                        .sectionCardStyle()
                        .padding(.horizontal)

                        Spacer()
                    }
                    .padding(.top, 8)
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
                    type: type,
                    selectedL1: $categoryL1,
                    selectedL2: $categoryL2
                )
                .id(type) // 强制按收支类型重建，避免 sheet 缓存导致显示错误分类
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
        .onAppear {
            // 初始化项目（列表+默认）
            let projectRepo = ProjectRepository(modelContext: modelContext)
            do {
                projects = try projectRepo.fetchAll()
                if let defaultProject = try projectRepo.fetchDefault() {
                    defaultProjectName = defaultProject.name
                    selectedProjectId = defaultProject.id
                } else if let first = projects.first {
                    defaultProjectName = first.name
                    selectedProjectId = first.id
                }
            } catch {
                // ignore
            }

            // 收入类型默认给个合理的初始分类
            if type == .income, categoryL2.isEmpty, let first = CategoryDictionary.incomeCategories.first {
                categoryL1 = "收入"
                categoryL2 = first
            }
        }
        .onChange(of: selectedProjectId) { _, newValue in
            if let id = newValue, let p = projects.first(where: { $0.id == id }) {
                defaultProjectName = p.name
            }
        }
    }

    private func saveTransaction() {
        // 验证
        guard !amount.isEmpty,
              let amountDecimal = Decimal(string: amount),
              amountDecimal > 0,
              !categoryL1.isEmpty,
              !categoryL2.isEmpty else {
            errorMessage = "请填写所有必填字段"
            return
        }

        // 获取选择的项目（默认=日常项目）
        let projectRepo = ProjectRepository(modelContext: modelContext)
        let project: Project?
        do {
            let all = try projectRepo.fetchAll()
            if let id = selectedProjectId {
                project = all.first(where: { $0.id == id })
            } else {
                project = try projectRepo.fetchDefault() ?? all.first
            }
        } catch {
            project = nil
        }
        guard let project else {
            errorMessage = "未找到项目"
            return
        }

        let amountMinor = Int64(truncating: (amountDecimal * Decimal(100)) as NSNumber)

        let transaction = Transaction(
            amountMinor: amountMinor,
            currency: currency,
            type: type,
            datetime: datetime,
            projectId: project.id,
            categoryL1: categoryL1,
            categoryL2: categoryL2,
            note: note
        )

        do {
            let repo = TransactionRepository(modelContext: modelContext)
            try repo.save(transaction)
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            dismiss()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
}

struct CategoryPickerView: View {
    let type: TransactionType

    @Binding var selectedL1: String
    @Binding var selectedL2: String
    @Environment(\.dismiss) private var dismiss

    // 支出用
    @State private var tempL1: String = ""
    @State private var tempL2: String = ""

    // 收入用
    @State private var tempIncome: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if type == .expense {
                    HStack(spacing: 0) {
                        // 一级分类
                        List(CategoryDictionary.expenseLevel1List, id: \.self) { level1 in
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
                        List(CategoryDictionary.expenseLevel2List(for: tempL1), id: \.self) { level2 in
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
                } else {
                    List(CategoryDictionary.incomeCategories, id: \.self) { item in
                        Button {
                            tempIncome = item
                            selectedL1 = "收入"
                            selectedL2 = item
                            dismiss()
                        } label: {
                            HStack {
                                Text(item)
                                Spacer()
                                if item == tempIncome {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
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
            if type == .expense {
                if !selectedL1.isEmpty {
                    tempL1 = selectedL1
                } else if let first = CategoryDictionary.expenseLevel1List.first {
                    tempL1 = first
                }
                tempL2 = selectedL2
            } else {
                tempIncome = selectedL2
                if tempIncome.isEmpty, let first = CategoryDictionary.incomeCategories.first {
                    tempIncome = first
                }
            }
        }
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
