import Foundation
import SwiftUI

class SettingsService {
    static let shared = SettingsService()
    
    private init() {}
    
    // Default settings values
    private let defaultSettings: [String: Any] = [
        "workTime": 25.0,
        "shortBreakTime": 5.0,
        "longBreakTime": 15.0,
        "sessionsUntilLongBreak": 4,
        "soundEnabled": true,
        "notificationsEnabled": true,
        "autoStartBreaks": false,
        "autoStartPomodoros": false
    ]
    
    func resetToDefaults() {
        // Reset timer settings
        UserDefaults.standard.set(defaultSettings["workTime"], forKey: "workTime")
        UserDefaults.standard.set(defaultSettings["shortBreakTime"], forKey: "shortBreakTime")
        UserDefaults.standard.set(defaultSettings["longBreakTime"], forKey: "longBreakTime")
        UserDefaults.standard.set(defaultSettings["sessionsUntilLongBreak"], forKey: "sessionsUntilLongBreak")
        
        // Reset notifications and sounds
        UserDefaults.standard.set(defaultSettings["soundEnabled"], forKey: "soundEnabled")
        UserDefaults.standard.set(defaultSettings["notificationsEnabled"], forKey: "notificationsEnabled")
        
        // Reset auto-start settings
        UserDefaults.standard.set(defaultSettings["autoStartBreaks"], forKey: "autoStartBreaks")
        UserDefaults.standard.set(defaultSettings["autoStartPomodoros"], forKey: "autoStartPomodoros")
        
        // Reset theme to system
        ThemeService.shared.currentTheme = .system
        
        // Reset timer colors to default
        ColorService.shared.colors = TimerColors.default
    }
} 