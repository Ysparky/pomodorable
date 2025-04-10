import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab.onChange(tabChanged)) {
            // Timer Tab
            NavigationView {
                TimerView()
                    .navigationTitle("app_name".localized)
            }
            .tabItem {
                Label("timer".localized, systemImage: "timer")
            }
            .tag(0)
            
            // History Tab
            HistoryView()
                .tabItem {
                    Label("history".localized, systemImage: "chart.bar")
                }
                .tag(1)
            
            // Settings Tab
            NavigationView {
                SettingsView()
                    .navigationTitle("settings".localized)
            }
            .tabItem {
                Label("settings".localized, systemImage: "gear")
            }
            .tag(2)
        }
        .onAppear {
            // Load the selected tab from UserDefaults if available
            if let savedTab = UserDefaults.standard.object(forKey: "selectedTab") as? Int {
                selectedTab = savedTab
            }
        }
    }
    
    private func tabChanged(to index: Int) {
        // Save the selected tab to UserDefaults
        UserDefaults.standard.set(index, forKey: "selectedTab")
        
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
