import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
