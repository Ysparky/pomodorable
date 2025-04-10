import SwiftUI

struct SettingsView: View {
    @AppStorage("workTime") private var workTime: Double = 25
    @AppStorage("shortBreakTime") private var shortBreakTime: Double = 5
    @AppStorage("longBreakTime") private var longBreakTime: Double = 15
    @AppStorage("sessionsUntilLongBreak") private var sessionsUntilLongBreak: Int = 4
    
    var body: some View {
        Form {
            Section(header: Text("Timer Duration (minutes)")) {
                VStack {
                    HStack {
                        Text("Work Time")
                        Spacer()
                        Text("\(Int(workTime))")
                    }
                    Slider(value: $workTime, in: 1...60, step: 1)
                }
                
                VStack {
                    HStack {
                        Text("Short Break")
                        Spacer()
                        Text("\(Int(shortBreakTime))")
                    }
                    Slider(value: $shortBreakTime, in: 1...30, step: 1)
                }
                
                VStack {
                    HStack {
                        Text("Long Break")
                        Spacer()
                        Text("\(Int(longBreakTime))")
                    }
                    Slider(value: $longBreakTime, in: 1...60, step: 1)
                }
            }
            
            Section(header: Text("Sessions")) {
                Stepper("Sessions until long break: \(sessionsUntilLongBreak)",
                        value: $sessionsUntilLongBreak,
                        in: 1...10)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
} 