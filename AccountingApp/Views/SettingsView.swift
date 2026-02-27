import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
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
                
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("更多")
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
    @State private var showShareSheet = false
    @State private var fileURL: URL?
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section("时间范围") {
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
            }
            
            Section {
                Button("导出Excel (CSV)") {
                    exportToCSV()
                }
            }
            
            Section {
                Text("导出的文件为CSV格式,可在Excel、Numbers或WPS中打开")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("导出")
        .sheet(isPresented: $showShareSheet) {
            if let url = fileURL {
                ShareSheet(items: [url])
            }
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
    
    private func exportToCSV() {
        let repo = TransactionRepository(modelContext: modelContext)
        let projectRepo = ProjectRepository(modelContext: modelContext)
        
        do {
            // 获取时间范围内的交易
            let transactions = try repo.fetch(from: startDate, to: endDate)
            
            // 获取所有项目(用于查找项目名)
            let projects = try projectRepo.fetchAll()
            let projectDict = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })
            
            // 生成CSV内容
            var csvText = "时间,类型,币种,金额,一级分类,二级分类,项目,备注\n"
            
            for transaction in transactions.sorted(by: { $0.datetime < $1.datetime }) {
                let dateStr = transaction.datetime.formatted(date: .numeric, time: .shortened)
                let type = transaction.type.rawValue
                let currency = transaction.currency.rawValue
                let amount = transaction.amount.formatted()
                let category1 = transaction.categoryL1
                let category2 = transaction.categoryL2
                let projectName = projectDict[transaction.projectId] ?? "未知项目"
                let note = transaction.note.replacingOccurrences(of: ",", with: "，") // 替换逗号避免CSV格式错误
                
                csvText += "\(dateStr),\(type),\(currency),\(amount),\(category1),\(category2),\(projectName),\(note)\n"
            }
            
            // 保存到临时文件
            let fileName = "账本导出_\(startDate.formatted(date: .numeric, time: .omitted))_\(endDate.formatted(date: .numeric, time: .omitted)).csv"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try csvText.write(to: tempURL, atomically: true, encoding: .utf8)
            
            fileURL = tempURL
            showShareSheet = true
            
        } catch {
            errorMessage = "导出失败: \(error.localizedDescription)"
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
