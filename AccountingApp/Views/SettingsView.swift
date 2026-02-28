import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    #if DEBUG
    @State private var showConfirmGenerateTestData = false
    #endif

    @State private var showTestDataAlert = false
    @State private var testDataResult = ""

    var body: some View {
        NavigationStack {
            List {
                Section("项目管理") {
                    NavigationLink(destination: ProjectListView()) {
                        Label("项目列表", systemImage: "folder")
                    }
                }

                Section("导出") {
                    NavigationLink(destination: ExportView()) {
                        Label("导出Excel", systemImage: "square.and.arrow.up")
                    }
                }

                #if DEBUG
                Section("开发") {
                    Button {
                        showConfirmGenerateTestData = true
                    } label: {
                        Label("生成测试数据", systemImage: "wand.and.stars")
                    }
                }
                #endif

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("更多")
            #if DEBUG
            .alert("确认生成测试数据？", isPresented: $showConfirmGenerateTestData) {
                Button("取消", role: .cancel) {}
                Button("确定") {
                    generateTestData()
                }
            } message: {
                Text("将向本地数据库插入一批测试流水，仅用于开发调试。")
            }
            #endif
            .alert("测试数据", isPresented: $showTestDataAlert) {
                Button("确定") {}
            } message: {
                Text(testDataResult)
            }
        }
    }
    
    private func generateTestData() {
        do {
            let count = try TestDataSeeder.seed(context: modelContext)
            testDataResult = "成功生成 \(count) 条测试数据"
            showTestDataAlert = true
        } catch {
            testDataResult = "生成失败: \(error.localizedDescription)"
            showTestDataAlert = true
        }
    }
}

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var projects: [Project] = []
    @State private var showAddProject = false
    @State private var newProjectName = ""
    @State private var errorMessage: String?
    @State private var editingProject: Project?
    @State private var editingName = ""
    @State private var deletingProject: Project?
    @State private var migrateToProject: Project?

    var body: some View {
        List {
            ForEach(projects) { project in
                HStack {
                    VStack(alignment: .leading) {
                        Text(project.name)
                            .font(.headline)
                        if project.isDefault {
                            Text("默认项目")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    Spacer()

                    Menu {
                        if !project.isDefault {
                            Button("设为默认") {
                                setDefault(project)
                            }
                        }

                        Button("重命名") {
                            editingProject = project
                            editingName = project.name
                        }

                        if !project.isDefault {
                            Button("删除", role: .destructive) {
                                deletingProject = project
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("项目管理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showAddProject = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("新建项目", isPresented: $showAddProject) {
            TextField("项目名称", text: $newProjectName)
            Button("取消", role: .cancel) {
                newProjectName = ""
            }
            Button("确定") {
                addProject()
            }
        }
        .alert("重命名项目", isPresented: .constant(editingProject != nil)) {
            TextField("项目名称", text: $editingName)
            Button("取消", role: .cancel) {
                editingProject = nil
                editingName = ""
            }
            Button("确定") {
                renameProject()
            }
        }
        .alert("删除项目", isPresented: .constant(deletingProject != nil)) {
            ForEach(projects.filter { $0.id != deletingProject?.id }, id: \.id) { project in
                Button(project.name) {
                    migrateToProject = project
                    deleteProject()
                }
            }
            Button("取消", role: .cancel) {
                deletingProject = nil
            }
        } message: {
            Text("选择要迁移到的项目:")
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
            loadProjects()
        }
    }

    private func loadProjects() {
        let repo = ProjectRepository(modelContext: modelContext)
        do {
            projects = try repo.fetchAll()
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }

    private func addProject() {
        guard !newProjectName.isEmpty else {
            errorMessage = "项目名称不能为空"
            return
        }

        let project = Project(name: newProjectName)
        let repo = ProjectRepository(modelContext: modelContext)
        do {
            try repo.save(project)
            newProjectName = ""
            loadProjects()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }

    private func setDefault(_ project: Project) {
        let repo = ProjectRepository(modelContext: modelContext)
        do {
            try repo.setDefault(project)
            loadProjects()
        } catch {
            errorMessage = "设置失败"
        }
    }

    private func renameProject() {
        guard let project = editingProject, !editingName.isEmpty else {
            errorMessage = "项目名称不能为空"
            return
        }

        project.name = editingName
        project.updatedAt = Date()

        do {
            try modelContext.save()
            editingProject = nil
            editingName = ""
            loadProjects()
        } catch {
            errorMessage = "重命名失败: \(error.localizedDescription)"
        }
    }

    private func deleteProject() {
        guard let project = deletingProject,
              let targetProject = migrateToProject else {
            errorMessage = "请选择迁移目标项目"
            return
        }

        let projectRepo = ProjectRepository(modelContext: modelContext)
        let transactionRepo = TransactionRepository(modelContext: modelContext)

        do {
            // 迁移交易
            try transactionRepo.updateProject(from: project.id, to: targetProject.id)

            // 删除项目
            try projectRepo.delete(project)

            deletingProject = nil
            migrateToProject = nil
            loadProjects()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
}

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var endDate = Date()
    @State private var shareItem: ShareItem?
    @State private var errorMessage: String?

    @State private var showImporter = false

    private func fileSafeDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    var body: some View {
        Form {
            Section("时间范围") {
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
            }

            Section {
                Button("导出Excel (XLS)") {
                    exportToXLS()
                }

                Button("导出CSV (兼容Excel)") {
                    exportToCSV()
                }
            }

            Section("导入") {
                Button("从文件导入（CSV/XLS）") {
                    showImporter = true
                }

                Text("把旧手机导出的CSV/XLS文件导入，可把流水迁移到新手机/新安装的App。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Text("XLS为Excel 2003 XML格式，直接用Excel打开即可；CSV也可用Excel/Numbers/WPS打开。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("导出")
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText, .data, .xml],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let count = try TransactionImporter.importFile(url: url, modelContext: modelContext)
                    errorMessage = "导入成功：\(count) 条"
                } catch {
                    errorMessage = error.localizedDescription
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("提示", isPresented: .constant(errorMessage != nil)) {
            Button("确定") {
                errorMessage = nil
            }
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
    }

    private func exportToCSV() {
        let repo = TransactionRepository(modelContext: modelContext)
        let projectRepo = ProjectRepository(modelContext: modelContext)

        do {
            let from = Calendar.current.startOfDay(for: startDate)
            let to = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
            let inclusiveEnd = to.addingTimeInterval(-1)
            let transactions = try repo.fetch(from: from, to: inclusiveEnd)

            let projects = try projectRepo.fetchAll()
            let projectDict = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })

            var csvText = "时间,类型,币种,金额,一级分类,二级分类,项目,备注\n"

            for transaction in transactions.sorted(by: { $0.datetime < $1.datetime }) {
                let dateStr = transaction.datetime.formatted(date: .numeric, time: .shortened)
                let type = transaction.type.rawValue
                let currency = transaction.currency.rawValue
                let amount = transaction.amount.formatted()
                let category1 = transaction.categoryL1
                let category2 = transaction.categoryL2
                let projectName = projectDict[transaction.projectId] ?? "未知项目"
                let note = transaction.note
                    .replacingOccurrences(of: ",", with: "，")
                    .replacingOccurrences(of: "\n", with: " ")

                csvText += "\(dateStr),\(type),\(currency),\(amount),\(category1),\(category2),\(projectName),\(note)\n"
            }

            let fileName = "账本导出_\(fileSafeDate(startDate))_\(fileSafeDate(endDate)).csv"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            try csvText.write(to: tempURL, atomically: true, encoding: .utf8)

            shareItem = ShareItem(url: tempURL)

        } catch {
            errorMessage = "导出失败: \(error.localizedDescription)"
        }
    }

    private func exportToXLS() {
        let repo = TransactionRepository(modelContext: modelContext)
        let projectRepo = ProjectRepository(modelContext: modelContext)

        do {
            let from = Calendar.current.startOfDay(for: startDate)
            let to = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
            let inclusiveEnd = to.addingTimeInterval(-1)
            let transactions = try repo.fetch(from: from, to: inclusiveEnd)

            let projects = try projectRepo.fetchAll()
            let projectDict = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })

            let headers = ["时间", "类型", "币种", "金额", "一级分类", "二级分类", "项目", "备注"]

            let rows: [[String]] = transactions
                .sorted(by: { $0.datetime < $1.datetime })
                .map { t in
                    let projectName = projectDict[t.projectId] ?? "未知项目"
                    return [
                        t.datetime.formatted(date: .numeric, time: .shortened),
                        t.type.rawValue,
                        t.currency.rawValue,
                        t.amount.formatted(),
                        t.categoryL1,
                        t.categoryL2,
                        projectName,
                        t.note
                    ]
                }

            let xml = ExcelXMLBuilder.buildWorkbook(sheetName: "流水", headers: headers, rows: rows)

            let fileName = "账本导出_\(fileSafeDate(startDate))_\(fileSafeDate(endDate)).xls"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            try xml.write(to: tempURL, atomically: true, encoding: .utf8)

            shareItem = ShareItem(url: tempURL)
        } catch {
            errorMessage = "导出失败: \(error.localizedDescription)"
        }
    }
}

/// Excel 2003 XML Spreadsheet (最轻量的“真Excel文件”写法)
enum ExcelXMLBuilder {
    static func buildWorkbook(sheetName: String, headers: [String], rows: [[String]]) -> String {
        let safeSheetName = xmlEscape(sheetName)

        func cell(_ value: String) -> String {
            let v = xmlEscape(value)
            return "<Cell><Data ss:Type=\"String\">\(v)</Data></Cell>"
        }

        let headerRow = "<Row>\(headers.map(cell).joined())</Row>"
        let bodyRows = rows.map { row in
            "<Row>\(row.map(cell).joined())</Row>"
        }.joined(separator: "\n")

        return """
<?xml version=\"1.0\"?>
<?mso-application progid=\"Excel.Sheet\"?>
<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\"
 xmlns:o=\"urn:schemas-microsoft-com:office:office\"
 xmlns:x=\"urn:schemas-microsoft-com:office:excel\"
 xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\"
 xmlns:html=\"http://www.w3.org/TR/REC-html40\">
  <Worksheet ss:Name=\"\(safeSheetName)\">
    <Table>
      \(headerRow)
      \(bodyRows)
    </Table>
  </Worksheet>
</Workbook>
"""
    }

    private static func xmlEscape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

// MARK: - 测试数据生成器
@MainActor
struct TestDataSeeder {
    static func seed(context: ModelContext) throws -> Int {
        // 获取或创建项目
        let projectNames = ["日常项目", "旅行项目", "装修项目", "投资项目"]
        var projects: [Project] = []
        
        for name in projectNames {
            let predicate = #Predicate<Project> { $0.name == name }
            let descriptor = FetchDescriptor<Project>(predicate: predicate)
            if let existing = try context.fetch(descriptor).first {
                projects.append(existing)
            } else {
                let project = Project(name: name, isDefault: name == "日常项目")
                context.insert(project)
                projects.append(project)
            }
        }
        
        try context.save()
        
        let calendar = Calendar.current
        let now = Date()
        var count = 0
        
        // 测试数据
        let testData: [(String, String, String, Double, String, String, Int, TransactionType)] = [
            ("日常", "吃饭", "SGD", 25.50, "日常项目", "午餐", 0, .expense),
            ("日常", "吃饭", "SGD", 18.00, "日常项目", "早餐", -1, .expense),
            ("购物", "数码产品", "SGD", 1299.00, "日常项目", "新手机", -2, .expense),
            ("娱乐", "聚会", "SGD", 156.80, "日常项目", "朋友聚餐", -3, .expense),
            ("出行", "地铁", "SGD", 3.50, "日常项目", "通勤", -4, .expense),
            ("日常", "日用品", "SGD", 45.60, "日常项目", "超市购物", -5, .expense),
            ("人情", "红包", "RMB", 200.00, "日常项目", "过年红包", -6, .expense),
            ("医疗", "药物", "SGD", 35.00, "日常项目", "感冒药", -7, .expense),
            ("住房", "房租", "SGD", 2500.00, "日常项目", "月租", -30, .expense),
            ("购物", "衣物", "SGD", 89.90, "日常项目", "T恤", -8, .expense),
            ("娱乐", "旅游", "SGD", 2500.00, "旅行项目", "日本游", -45, .expense),
            ("出行", "机票", "USD", 800.00, "旅行项目", "国际航班", -50, .expense),
            ("住房", "物管费", "SGD", 150.00, "装修项目", "管理费", -10, .expense),
            ("购物", "书", "SGD", 45.00, "日常项目", "技术书籍", -12, .expense),
            ("金融", "投资", "SGD", 5000.00, "投资项目", "股票买入", -1, .expense),
            ("收入", "工资收入", "SGD", 5000.00, "日常项目", "月薪", -30, .income),
            ("收入", "红包收入", "RMB", 88.88, "日常项目", "春节红包", -15, .income),
            ("收入", "奖金收入", "SGD", 2000.00, "日常项目", "年终奖", -20, .income),
            ("收入", "工资收入", "USD", 3000.00, "日常项目", "美金工资", -30, .income),
            ("收入", "其他收入", "SGD", 500.00, "投资项目", "投资收益", -5, .income),
        ]
        
        for data in testData {
            let date = calendar.date(byAdding: .day, value: data.6, to: now)!
            let project = projects.first { $0.name == data.4 }!
            
            var currency: Currency = .sgd
            if data.2 == "RMB" { currency = .rmb }
            if data.2 == "USD" { currency = .usd }
            
            let transaction = Transaction(
                amountMinor: Int64(data.3 * 100),
                currency: currency,
                type: data.7,
                datetime: date,
                projectId: project.id,
                categoryL1: data.0,
                categoryL2: data.1,
                note: data.5
            )
            context.insert(transaction)
            count += 1
        }
        
        try context.save()
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        return count
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
