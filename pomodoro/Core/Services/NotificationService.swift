import Foundation
import UserNotifications

enum TimerMode {
    case work
    case break_
}

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
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
        
        // For in-app notifications when in different tab (foreground), deliver immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error al programar notificación: \(error.localizedDescription)")
            }
        }
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
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error al programar notificación: \(error.localizedDescription)")
            }
        }
    }
    
    // Cancel scheduled timer notifications
    func cancelPendingTimerNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timerEndNotification"])
    }
} 