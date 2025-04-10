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
    @StateObject private var historyViewModel = HistoryViewModel()
    
    @State private var showResetConfirmAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("timer_duration".localized)) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("work_time".localized)
                        Spacer()
                        Text("\(Int(workTime)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { workTime },
                        set: { newValue in
                            workTime = newValue
                            // Send notification for duration change
                            NotificationCenter.default.post(name: SettingsViewModel.durationChangedNotification, object: nil)
                        }
                    ), in: 1...60, step: 1)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("short_break".localized)
                        Spacer()
                        Text("\(Int(shortBreakTime)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { shortBreakTime },
                        set: { newValue in
                            shortBreakTime = newValue
                            // Send notification for duration change
                            NotificationCenter.default.post(name: SettingsViewModel.durationChangedNotification, object: nil)
                        }
                    ), in: 1...30, step: 1)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("long_break".localized)
                        Spacer()
                        Text("\(Int(longBreakTime)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { longBreakTime },
                        set: { newValue in
                            longBreakTime = newValue
                            // Send notification for duration change
                            NotificationCenter.default.post(name: SettingsViewModel.durationChangedNotification, object: nil)
                        }
                    ), in: 1...60, step: 1)
                }
            }
            
            Section(header: Text("sessions".localized)) {
                Stepper("sessions_count".localizedWithArg(sessionsUntilLongBreak),
                        value: Binding(
                            get: { sessionsUntilLongBreak },
                            set: { newValue in
                                sessionsUntilLongBreak = newValue
                                // Send notification for sessions change
                                NotificationCenter.default.post(name: SettingsViewModel.sessionsChangedNotification, object: nil)
                            }
                        ),
                        in: 1...10)
            }
            
            Section(header: Text("notifications".localized)) {
                Toggle("enable_sounds".localized, isOn: $soundEnabled)
                Toggle("enable_notifications".localized, isOn: $notificationsEnabled)
            }
            
            Section(header: Text("auto_start".localized)) {
                Toggle("auto_start_breaks".localized, isOn: $autoStartBreaks)
                Toggle("auto_start_pomodoros".localized, isOn: $autoStartPomodoros)
            }
            
            // iCloud sync section
            Section(header: Text("sync".localized)) {
                Toggle("sync_with_icloud".localized, isOn: $historyViewModel.isCloudSyncEnabled)
                    .onChange(of: historyViewModel.isCloudSyncEnabled) { oldValue, newValue in
                        historyViewModel.toggleCloudSync()
                    }
                
                HStack {
                    Text("last_sync".localized)
                    Spacer()
                    Text(historyViewModel.lastSyncFormatted)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    historyViewModel.syncWithCloud()
                }) {
                    HStack {
                        Text("sync_now".localized)
                        Spacer()
                        if historyViewModel.isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
                .disabled(historyViewModel.isSyncing || !historyViewModel.isCloudSyncEnabled)
                
                if let error = historyViewModel.syncError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("appearance".localized)) {
                Picker("theme".localized, selection: $viewModel.themeService.currentTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("timer_colors".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("work".localized)
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
                        Text("break".localized)
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
            
            Section(header: Text("info".localized)) {
                HStack {
                    Text("version".localized)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
            
            // Restore Default Settings Section
            Section(header: Text("other_options".localized)) {
                Button(action: {
                    showResetConfirmAlert = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.red)
                        Text("restore_defaults".localized)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("settings".localized)
        .alert(isPresented: $showResetConfirmAlert) {
            Alert(
                title: Text("restore_defaults".localized),
                message: Text("restore_confirmation".localized),
                primaryButton: .destructive(Text("restore".localized)) {
                    resetToDefaultSettings()
                },
                secondaryButton: .cancel(Text("cancel".localized))
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
        
        // Send notifications for relevant changes
        NotificationCenter.default.post(name: SettingsViewModel.durationChangedNotification, object: nil)
        NotificationCenter.default.post(name: SettingsViewModel.sessionsChangedNotification, object: nil)
        
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