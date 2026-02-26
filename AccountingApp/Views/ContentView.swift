import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showAddTransaction = false
    
    var body: some View {
        ZStack {
            MainTabView()
            
            // 全局浮动按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showAddTransaction = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showAddTransaction) {
            AddTransactionView()
        }
        .onAppear {
            initializeDefaultProject()
        }
    }
    
    private func initializeDefaultProject() {
        let repository = ProjectRepository(modelContext: modelContext)
        try? repository.initializeDefaultProject()
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TransactionListView()
                .tabItem {
                    Label("流水", systemImage: "list.bullet")
                }
            
            ReportView()
                .tabItem {
                    Label("报表", systemImage: "chart.bar")
                }
            
            SettingsView()
                .tabItem {
                    Label("更多", systemImage: "ellipsis.circle")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Project.self], inMemory: true)
}
