import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notificación autorizada")
            } else if let error = error {
                print("Error al autorizar notificaciones: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotification(for mode: TimerMode) {
        let content = UNMutableNotificationContent()
        content.title = mode == .work ? "¡Tiempo de descanso!" : "¡Tiempo de trabajo!"
        content.body = mode == .work ? "Has completado tu sesión de trabajo. Toma un descanso." : "El descanso ha terminado. ¡Vuelve al trabajo!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}

enum TimerMode {
    case work
    case break_
} 