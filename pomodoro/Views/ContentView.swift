import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            TimerView()
                .navigationTitle("Pomodoro")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gear")
                        }
                    }
                }
        }
    }
}

#Preview {
    ContentView()
} 
