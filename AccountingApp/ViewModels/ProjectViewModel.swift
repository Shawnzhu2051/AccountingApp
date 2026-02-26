import Foundation
import SwiftData

@MainActor
class ProjectViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var errorMessage: String?
    
    private let repository: ProjectRepository
    private let transactionRepository: TransactionRepository
    
    init(modelContext: ModelContext) {
        self.repository = ProjectRepository(modelContext: modelContext)
        self.transactionRepository = TransactionRepository(modelContext: modelContext)
    }
    
    func loadProjects() {
        do {
            projects = try repository.fetchAll()
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }
    
    func addProject(name: String) {
        guard !name.isEmpty else {
            errorMessage = "项目名称不能为空"
            return
        }
        
        let project = Project(name: name)
        do {
            try repository.save(project)
            loadProjects()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
    
    func updateProject(_ project: Project, name: String) {
        guard !name.isEmpty else {
            errorMessage = "项目名称不能为空"
            return
        }
        
        project.name = name
        do {
            try repository.update(project)
            loadProjects()
        } catch {
            errorMessage = "更新失败: \(error.localizedDescription)"
        }
    }
    
    func setDefault(_ project: Project) {
        do {
            try repository.setDefault(project)
            loadProjects()
        } catch {
            errorMessage = "设置默认项目失败"
        }
    }
    
    func deleteProject(_ project: Project, migrateToId: UUID) {
        do {
            // 迁移交易到目标项目
            try transactionRepository.updateProject(from: project.id, to: migrateToId)
            
            // 删除项目
            try repository.delete(project)
            
            loadProjects()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
    
    func initializeDefault() {
        do {
            try repository.initializeDefaultProject()
            loadProjects()
        } catch {
            errorMessage = "初始化失败"
        }
    }
}
