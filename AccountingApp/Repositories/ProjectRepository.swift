import Foundation
import SwiftData

@MainActor
class ProjectRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // 获取所有项目
    func fetchAll() throws -> [Project] {
        let descriptor = FetchDescriptor<Project>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    // 获取默认项目
    func fetchDefault() throws -> Project? {
        let predicate = #Predicate<Project> { project in
            project.isDefault == true
        }
        let descriptor = FetchDescriptor<Project>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    // 保存
    func save(_ project: Project) throws {
        modelContext.insert(project)
        try modelContext.save()
    }
    
    // 更新
    func update(_ project: Project) throws {
        project.updatedAt = Date()
        try modelContext.save()
    }
    
    // 设置默认项目
    func setDefault(_ project: Project) throws {
        // 先清除所有默认标记
        let all = try fetchAll()
        for p in all {
            p.isDefault = false
        }
        
        // 设置新的默认项目
        project.isDefault = true
        try modelContext.save()
    }
    
    // 删除项目
    func delete(_ project: Project) throws {
        modelContext.delete(project)
        try modelContext.save()
    }
    
    // 初始化默认项目
    func initializeDefaultProject() throws {
        let existing = try fetchAll()
        if existing.isEmpty {
            let defaultProject = Project(name: "日常项目", isDefault: true)
            try save(defaultProject)
        }
    }
}
