import Foundation
import UserNotifications
import UIKit

enum TimerMode {
    case work
    case break_
}

class NotificationService: NSObject {
    static let shared = NotificationService()
    
    // Notification for when the authorization status changes
    static let notificationAuthorizationChangedNotification = Notification.Name("NotificationAuthorizationChanged")
    
    // Notification authorization status
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private override init() {
        super.init()
        // Set the notification delegate when the service is initialized
        UNUserNotificationCenter.current().delegate = self
        
        // Check the current authorization status
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                
                // If the user has enabled notifications in the settings, 
                // but they are disabled in the app, activate them
                if settings.authorizationStatus == .authorized {
                    if !UserDefaults.standard.bool(forKey: "notificationsEnabled") {
                        UserDefaults.standard.set(true, forKey: "notificationsEnabled")
                    }
                }
                
                // Notify the status change
                NotificationCenter.default.post(name: NotificationService.notificationAuthorizationChangedNotification, object: settings.authorizationStatus)
            }
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification authorized")
                    // If authorized, activate notifications in the app automatically
                    UserDefaults.standard.set(true, forKey: "notificationsEnabled")
                } else if let error = error {
                    print("Error authorizing notifications: \(error.localizedDescription)")
                    // If denied, disable notifications in the app
                    UserDefaults.standard.set(false, forKey: "notificationsEnabled")
                }
                
                // Update the authorization status
                self.checkAuthorizationStatus()
            }
        }
    }
    
    // Method to open the system notification settings
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    func scheduleNotification(for mode: TimerMode) {
        // Check if notifications are enabled
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = mode == .work ? "break_time_notification_title".localized : "work_time_notification_title".localized
        content.body = mode == .work ? "break_time_notification_body".localized : "work_time_notification_body".localized
        
        // Only add sound if enabled in settings
        if UserDefaults.standard.bool(forKey: "soundEnabled") {
            content.sound = .default
        }
        
        // Add user info to identify foreground notifications
        if UIApplication.shared.applicationState == .active {
            content.userInfo = ["foregroundNotification": true]
        }
        
        // Use a fixed identifier for foreground notifications so they can be handled properly
        let identifier = UIApplication.shared.applicationState == .active ? 
            "foregroundTimerNotification" : UUID().uuidString
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // Function to schedule a notification that will trigger when the timer ends
    // Useful for when the app is in the background
    func scheduleTimerEndNotification(timeRemaining: Int, isWorkMode: Bool) {
        // Cancel pending notifications first
        cancelPendingTimerNotifications()
        
        // Check if notifications are enabled
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        
        let content = UNMutableNotificationContent()
        
        if isWorkMode {
            content.title = "break_time_notification_title".localized
            content.body = "break_time_notification_body".localized
        } else {
            content.title = "work_time_notification_title".localized
            content.body = "work_time_notification_body".localized
        }
        
        // Only add sound if enabled in settings
        if UserDefaults.standard.bool(forKey: "soundEnabled") {
            content.sound = .default
        }
        
        // Schedule the notification to trigger exactly when the time ends
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(timeRemaining), repeats: false)
        let request = UNNotificationRequest(identifier: "timerEndNotification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // Cancel scheduled timer notifications
    func cancelPendingTimerNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timerEndNotification", "foregroundTimerNotification"])
    }
    
    // Method to post a notification to switch to the timer tab
    func postSwitchToTimerTabNotification() {
        NotificationCenter.default.post(name: .switchToTimerTab, object: nil)
    }
}

// Extension to handle notification presentation when app is in foreground
extension NotificationService: UNUserNotificationCenterDelegate {
    // This method allows the notification to be shown even when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification, 
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Add a user info value to detect when the notification was displayed while the app was in foreground
        _ = notification.request.content.userInfo
        
        // Check if we're in the timer tab
        if !isTimerTabSelected() {
            // If not in timer tab, show notification with banner and sound
            completionHandler([.banner, .sound])
        } else {
            // We're already in the timer tab, don't show the notification
            completionHandler([])
        }
    }
    
    // Helper to check if timer tab is selected
    private func isTimerTabSelected() -> Bool {
        return UserDefaults.standard.integer(forKey: "selectedTab") == 0
    }
    
    // This method handles the user's response to a delivered notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // Set the selected tab to Timer tab (0) when app is opened from notification
        UserDefaults.standard.set(0, forKey: "selectedTab")
        
        // Post notification to switch to timer tab
        postSwitchToTimerTabNotification()
        
        // Cancel any pending notifications since the user is now in the app
        cancelPendingTimerNotifications()
        
        completionHandler()
    }
} 
