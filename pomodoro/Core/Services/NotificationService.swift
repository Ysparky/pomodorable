import Foundation
import UserNotifications

enum TimerMode {
    case work
    case break_
}

class NotificationService: NSObject {
    static let shared = NotificationService()
    
    private override init() {
        super.init()
        // Set the notification delegate when the service is initialized
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notificación autorizada")
            } else if let error = error {
                print("Error al autorizar notificaciones: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotification(for mode: TimerMode) {
        // Check if notifications are enabled
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = mode == .work ? "¡Tiempo de descanso!" : "¡Tiempo de trabajo!"
        content.body = mode == .work ? "Has completado tu sesión de trabajo. Toma un descanso." : "El descanso ha terminado. ¡Vuelve al trabajo!"
        
        // Only add sound if enabled in settings
        if UserDefaults.standard.bool(forKey: "soundEnabled") {
            content.sound = .default
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
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
            content.title = "¡Tiempo de descanso!"
            content.body = "Has completado tu sesión de trabajo. Toma un descanso."
        } else {
            content.title = "¡Tiempo de trabajo!"
            content.body = "El descanso ha terminado. ¡Vuelve al trabajo!"
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
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timerEndNotification"])
    }
}

// Extension to handle notification presentation when app is in foreground
extension NotificationService: UNUserNotificationCenterDelegate {
    // This method allows the notification to be shown even when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification, 
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification with banner and sound when in foreground
        completionHandler([.banner, .sound, .badge])
    }
} 