import SwiftUI

class SettingsViewModel: ObservableObject {
    // Referencias a los servicios compartidos
    @Published var themeService = ThemeService.shared
    @Published var colorService = ColorService.shared
    
    // Notification names for settings changes
    static let durationChangedNotification = Notification.Name("DurationSettingsChanged")
    static let sessionsChangedNotification = Notification.Name("SessionsSettingsChanged")
    
    // Method to reset the settings to default
    func resetToDefaultSettings() {
        SettingsService.shared.resetToDefaults()
    }
    
    // Methods to get timer settings values in seconds
    func getWorkTime() -> Int {
        Int(UserDefaults.standard.double(forKey: "workTime") * 60)
    }
    
    func getShortBreakTime() -> Int {
        Int(UserDefaults.standard.double(forKey: "shortBreakTime") * 60)
    }
    
    func getLongBreakTime() -> Int {
        Int(UserDefaults.standard.double(forKey: "longBreakTime") * 60)
    }
    
    func getBreakTime(shouldTakeLongBreak: Bool) -> Int {
        shouldTakeLongBreak ? getLongBreakTime() : getShortBreakTime()
    }
    
    func getSessionsUntilLongBreak() -> Int {
        UserDefaults.standard.integer(forKey: "sessionsUntilLongBreak")
    }
    
    func shouldAutoStartBreaks() -> Bool {
        UserDefaults.standard.bool(forKey: "autoStartBreaks")
    }
    
    func shouldAutoStartPomodoros() -> Bool {
        UserDefaults.standard.bool(forKey: "autoStartPomodoros")
    }
}
