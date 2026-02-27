import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showAddTransaction = false
    
    var body: some View {
        ZStack {
            MainTabView()
            
            // 优化的浮动按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showAddTransaction = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.accentBlue, .accentBlue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .shadow(color: .accentBlue.opacity(0.3), radius: 12, x: 0, y: 6)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
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
