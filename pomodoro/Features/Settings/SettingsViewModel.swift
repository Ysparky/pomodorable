import SwiftUI
import UserNotifications

class SettingsViewModel: ObservableObject {
    // References to shared services
    @Published var themeService = ThemeService.shared
    @Published var colorService = ColorService.shared
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    // Notification names for settings changes
    static let durationChangedNotification = Notification.Name("DurationSettingsChanged")
    static let sessionsChangedNotification = Notification.Name("SessionsSettingsChanged")
    static let notificationStatusChangedNotification = Notification.Name("NotificationStatusChanged")
    
    init() {
        // Observe the changes in the notification authorization status
        setupObservers()
        // Check the current notification permission status
        checkNotificationStatus()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotificationStatusChanged),
            name: NotificationService.notificationAuthorizationChangedNotification,
            object: nil
        )
    }
    
    @objc private func handleNotificationStatusChanged(notification: Notification) {
        if let status = notification.object as? UNAuthorizationStatus {
            DispatchQueue.main.async {
                self.notificationStatus = status
                // Propagate the status change to the SettingsView
                NotificationCenter.default.post(
                    name: SettingsViewModel.notificationStatusChangedNotification,
                    object: status
                )
            }
        }
    }
    
    func checkNotificationStatus() {
        // Get the current notification permission status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestNotificationPermission() {
        NotificationService.shared.requestAuthorization()
    }
    
    func openSystemSettings() {
        NotificationService.shared.openAppSettings()
    }
    
    // Method to reset the settings to default
    func resetToDefaultSettings() {
        SettingsService.shared.resetToDefaults()
    }
    
    // Methods to get timer settings values in seconds
    func getWorkTime() -> Int {
        let workTime = UserDefaults.standard.double(forKey: "workTime")
        // If it doesn't exist or is zero, use the default value (25 minutes)
        return workTime > 0 ? Int(workTime * 60) : 25 * 60
    }
    
    func getShortBreakTime() -> Int {
        let shortBreakTime = UserDefaults.standard.double(forKey: "shortBreakTime")
        // If it doesn't exist or is zero, use the default value (5 minutes)
        return shortBreakTime > 0 ? Int(shortBreakTime * 60) : 5 * 60
    }
    
    func getLongBreakTime() -> Int {
        let longBreakTime = UserDefaults.standard.double(forKey: "longBreakTime")
        // If it doesn't exist or is zero, use the default value (15 minutes)
        return longBreakTime > 0 ? Int(longBreakTime * 60) : 15 * 60
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
