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
    
    @StateObject private var viewModel = SettingsViewModel()
    
    @State private var showResetConfirmAlert = false
    
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
            
            Section(header: Text("Apariencia")) {
                Picker("Tema", selection: $viewModel.themeService.currentTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Colores del temporizador")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Trabajo")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { viewModel.colorService.colors.workColor },
                            set: { newColor in
                                var colors = viewModel.colorService.colors
                                colors.workColor = newColor
                                viewModel.colorService.colors = colors
                            }
                        ))
                    }
                    
                    HStack {
                        Text("Descanso")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { viewModel.colorService.colors.breakColor },
                            set: { newColor in
                                var colors = viewModel.colorService.colors
                                colors.breakColor = newColor
                                viewModel.colorService.colors = colors
                            }
                        ))
                    }
                }
            }
            
            Section(header: Text("Información")) {
                HStack {
                    Text("Versión")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
            
            // Restore Default Settings Section
            Section(header: Text("Otras opciones")) {
                Button(action: {
                    showResetConfirmAlert = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.red)
                        Text("Restaurar configuración por defecto")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("Configuración")
        .alert(isPresented: $showResetConfirmAlert) {
            Alert(
                title: Text("Restaurar configuración"),
                message: Text("¿Estás seguro de que deseas restaurar toda la configuración a los valores por defecto?"),
                primaryButton: .destructive(Text("Restaurar")) {
                    resetToDefaultSettings()
                },
                secondaryButton: .cancel(Text("Cancelar"))
            )
        }
    }
    
    private func resetToDefaultSettings() {
        // Call the method in ViewModel
        viewModel.resetToDefaultSettings()
        
        // Update local state to reflect the default values
        workTime = 25
        shortBreakTime = 5
        longBreakTime = 15
        sessionsUntilLongBreak = 4
        autoStartPomodoros = false
        autoStartBreaks = false
        notificationsEnabled = true
        soundEnabled = true
        
        // The ColorService is already updated by the SettingsService but we need to
        // trigger a UI update
        viewModel.colorService.objectWillChange.send()
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
} 