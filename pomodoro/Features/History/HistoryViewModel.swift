import Foundation
import Combine
import SwiftUI

class HistoryViewModel: ObservableObject {
    @Published var dailySessions: [PomodoroSession] = []
    @Published var weeklySessions: [PomodoroSession] = []
    @Published var monthlySessions: [PomodoroSession] = []
    @Published var stats: HistoryService.PomodoroStats = HistoryService.PomodoroStats()
    
    @Published var selectedTimeframe: Timeframe = .daily
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case daily = "Hoy"
        case weekly = "Esta Semana"
        case monthly = "Este Mes"
        
        var id: String { self.rawValue }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initial load
        refreshHistory()
        
        // Setup notification for when a new session is added
        NotificationCenter.default.publisher(for: .newPomodoroSessionAdded)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshHistory()
            }
            .store(in: &cancellables)
        
        // Observer for app returning to foreground to refresh data
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshHistory()
            }
            .store(in: &cancellables)
        
        // Observer for tab selection changes
        NotificationCenter.default.publisher(for: .historyTabSelected)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshHistory()
            }
            .store(in: &cancellables)
        
        // Create timer to periodically refresh the data every minute
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshHistory()
            }
            .store(in: &cancellables)
    }
    
    func refreshHistory() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dailySessions = HistoryService.shared.getSessionsForCurrentDay()
            self.weeklySessions = HistoryService.shared.getSessionsForCurrentWeek()
            self.monthlySessions = HistoryService.shared.getSessionsForCurrentMonth()
            self.stats = HistoryService.shared.getStats()
            
            // Force UI update by triggering objectWillChange
            self.objectWillChange.send()
        }
    }
    
    func clearAllHistory() {
        HistoryService.shared.clearAllHistory()
        refreshHistory()
    }
    
    func clearHistoryOlderThan30Days() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        HistoryService.shared.clearHistoryOlderThan(thirtyDaysAgo)
        refreshHistory()
    }
    
    // MARK: - Computed Properties
    
    var totalSessionsForSelectedTimeframe: Int {
        switch selectedTimeframe {
        case .daily:
            return dailySessions.filter { $0.isCompleted }.count
        case .weekly:
            return weeklySessions.filter { $0.isCompleted }.count
        case .monthly:
            return monthlySessions.filter { $0.isCompleted }.count
        }
    }
    
    var totalMinutesForSelectedTimeframe: Int {
        let sessions = sessionsForSelectedTimeframe.filter { $0.isCompleted }
        let totalSeconds = sessions.reduce(0) { $0 + $1.duration }
        return Int(totalSeconds / 60)
    }
    
    var sessionsForSelectedTimeframe: [PomodoroSession] {
        switch selectedTimeframe {
        case .daily:
            return dailySessions
        case .weekly:
            return weeklySessions
        case .monthly:
            return monthlySessions
        }
    }
    
    var sessionsByDay: [String: [PomodoroSession]] {
        Dictionary(grouping: sessionsForSelectedTimeframe) { $0.dayString }
    }
    
    var sessionsByTimeOfDay: [String: [PomodoroSession]] {
        Dictionary(grouping: sessionsForSelectedTimeframe) { $0.timeOfDayString }
    }
    
    var mostProductiveTimeOfDay: String? {
        let groupedSessions = sessionsByTimeOfDay
        guard !groupedSessions.isEmpty else { return nil }
        
        let mostProductiveEntry = groupedSessions.max { a, b in
            let aCompleted = a.value.filter { $0.isCompleted }.count
            let bCompleted = b.value.filter { $0.isCompleted }.count
            return aCompleted < bCompleted
        }
        
        return mostProductiveEntry?.key
    }
    
    // MARK: - Chart Data Helpers
    
    // Devuelve estadísticas de productividad por día de la semana (para identificar patrones semanales)
    var productivityByDayOfWeek: [String: (sessions: Int, minutes: Int)] {
        let completedSessions = monthlySessions.filter { $0.isCompleted }
        let calendar = Calendar.current
        
        // Inicializando con los días de la semana para asegurar que todos estén incluidos
        var result: [String: (sessions: Int, minutes: Int)] = [
            "Lun": (0, 0), "Mar": (0, 0), "Mié": (0, 0), "Jue": (0, 0),
            "Vie": (0, 0), "Sáb": (0, 0), "Dom": (0, 0)
        ]
        
        // Agrupando por día de la semana
        for session in completedSessions {
            let weekday = calendar.component(.weekday, from: session.startTime)
            let dayName = getDayOfWeekName(weekday: weekday)
            let minutes = Int(session.duration / 60)
            
            if var existing = result[dayName] {
                existing.sessions += 1
                existing.minutes += minutes
                result[dayName] = existing
            }
        }
        
        return result
    }
    
    // Devuelve la duración promedio de las sesiones por día
    var averageSessionDurationByDay: [String: Double] {
        let sessionsByDay = Dictionary(grouping: sessionsForSelectedTimeframe.filter { $0.isCompleted }) { $0.dayString }
        
        return sessionsByDay.mapValues { sessions in
            let totalDuration = sessions.reduce(0) { $0 + $1.duration }
            return totalDuration / Double(sessions.count) / 60 // Convertir a minutos
        }
    }
    
    // Devuelve el número de sesiones completadas por día para un rango de fechas
    func completedSessionsCountForRange(_ dates: [Date]) -> [Int] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return dates.map { date in
            let dateString = dateFormatter.string(from: date)
            let sessionsForDate = sessionsForSelectedTimeframe.filter { 
                $0.dayString == dateString && $0.isCompleted 
            }
            return sessionsForDate.count
        }
    }
    
    // MARK: - Helper Functions
    
    private func getDayOfWeekName(weekday: Int) -> String {
        // weekday: 1 = Domingo, 2 = Lunes, ..., 7 = Sábado
        switch weekday {
        case 1: return "Dom"
        case 2: return "Lun"
        case 3: return "Mar"
        case 4: return "Mié"
        case 5: return "Jue"
        case 6: return "Vie"
        case 7: return "Sáb"
        default: return ""
        }
    }
}

// Notification for when a new Pomodoro session is added
extension Notification.Name {
    static let newPomodoroSessionAdded = Notification.Name("newPomodoroSessionAdded")
    static let historyTabSelected = Notification.Name("historyTabSelected")
} 