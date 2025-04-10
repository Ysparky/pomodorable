import SwiftUI

struct SettingsView: View {
    @AppStorage("workTime") private var workTime: Double = 25
    @AppStorage("shortBreakTime") private var shortBreakTime: Double = 5
    @AppStorage("longBreakTime") private var longBreakTime: Double = 15
    @AppStorage("sessionsUntilLongBreak") private var sessionsUntilLongBreak: Int = 4
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("autoStartBreaks") private var autoStartBreaks: Bool = false
    @AppStorage("autoStartPomodoros") private var autoStartPomodoros: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("Duración del Temporizador")) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Tiempo de trabajo")
                        Spacer()
                        Text("\(Int(workTime)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $workTime, in: 1...60, step: 1)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Descanso corto")
                        Spacer()
                        Text("\(Int(shortBreakTime)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $shortBreakTime, in: 1...30, step: 1)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Descanso largo")
                        Spacer()
                        Text("\(Int(longBreakTime)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $longBreakTime, in: 1...60, step: 1)
                }
            }
            
            Section(header: Text("Sesiones")) {
                Stepper("Sesiones hasta descanso largo: \(sessionsUntilLongBreak)",
                        value: $sessionsUntilLongBreak,
                        in: 1...10)
            }
            
            Section(header: Text("Notificaciones")) {
                Toggle("Activar sonidos", isOn: $soundEnabled)
                Toggle("Activar notificaciones", isOn: $notificationsEnabled)
            }
            
            Section(header: Text("Auto-inicio")) {
                Toggle("Iniciar descansos automáticamente", isOn: $autoStartBreaks)
                Toggle("Iniciar pomodoros automáticamente", isOn: $autoStartPomodoros)
            }
            
            Section(header: Text("Información")) {
                HStack {
                    Text("Versión")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Configuración")
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
} 