import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab.onChange(tabChanged)) {
            // Timer Tab
            NavigationView {
                TimerView()
                    .navigationTitle("Pomodoro")
            }
            .tabItem {
                Label("Temporizador", systemImage: "timer")
            }
            .tag(0)
            
            // History Tab
            HistoryView()
                .tabItem {
                    Label("Historial", systemImage: "chart.bar")
                }
                .tag(1)
            
            // Settings Tab
            NavigationView {
                SettingsView()
                    .navigationTitle("Ajustes")
            }
            .tabItem {
                Label("Ajustes", systemImage: "gear")
            }
            .tag(2)
        }
    }
    
    private func tabChanged(to index: Int) {
        if index == 1 { // History tab
            NotificationCenter.default.post(name: .historyTabSelected, object: nil)
        }
    }
}

// Extension to handle onChange event for Binding
extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

#Preview {
    ContentView()
} 
