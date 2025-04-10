import Foundation
import Combine

class HistoryViewModel: ObservableObject {
    @Published var dailySessions: [PomodoroSession] = []
    @Published var weeklySessions: [PomodoroSession] = []
    @Published var monthlySessions: [PomodoroSession] = []
    @Published var stats: HistoryService.PomodoroStats = HistoryService.PomodoroStats()
    
    @Published var selectedTimeframe: Timeframe = .daily
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case daily = "Today"
        case weekly = "This Week"
        case monthly = "This Month"
        
        var id: String { self.rawValue }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initial load
        refreshHistory()
        
        // Setup notification for when a new session is added
        NotificationCenter.default.publisher(for: .newPomodoroSessionAdded)
            .sink { [weak self] _ in
                self?.refreshHistory()
            }
            .store(in: &cancellables)
    }
    
    func refreshHistory() {
        dailySessions = HistoryService.shared.getSessionsForCurrentDay()
        weeklySessions = HistoryService.shared.getSessionsForCurrentWeek()
        monthlySessions = HistoryService.shared.getSessionsForCurrentMonth()
        stats = HistoryService.shared.getStats()
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
}

// Notification for when a new Pomodoro session is added
extension Notification.Name {
    static let newPomodoroSessionAdded = Notification.Name("newPomodoroSessionAdded")
} 