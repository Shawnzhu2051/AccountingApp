import SwiftUI
import SwiftData

@main
struct AccountingAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Transaction.self, Project.self])
    }
}
