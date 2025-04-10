import Foundation

class HistoryService {
    static let shared = HistoryService()
    
    private let sessionsKey = "pomodoro_sessions"
    private let statsKey = "pomodoro_stats"
    
    // Statistics structure to store aggregate data
    struct PomodoroStats: Codable {
        var totalSessions: Int = 0
        var totalTime: TimeInterval = 0
        var mostProductiveDay: String = ""
        var mostProductiveDayCount: Int = 0
        var lastUpdated: Date = Date()
    }
    
    private init() {}
    
    // MARK: - Session Management
    
    func savePomodoroSession(_ session: PomodoroSession) {
        var sessions = getAllSessions()
        sessions.append(session)
        saveAllSessions(sessions)
        updateStats(with: session)
        
        // Post notification for observers
        NotificationCenter.default.post(name: .newPomodoroSessionAdded, object: nil)
    }
    
    func getAllSessions() -> [PomodoroSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey) else { return [] }
        
        do {
            return try JSONDecoder().decode([PomodoroSession].self, from: data)
        } catch {
            print("Error decoding Pomodoro sessions: \(error.localizedDescription)")
            return []
        }
    }
    
    private func saveAllSessions(_ sessions: [PomodoroSession]) {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: sessionsKey)
        } catch {
            print("Error encoding Pomodoro sessions: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Session Filtering
    
    func getSessionsForDay(_ date: Date) -> [PomodoroSession] {
        let calendar = Calendar.current
        return getAllSessions().filter { session in
            calendar.isDate(session.startTime, inSameDayAs: date)
        }
    }
    
    func getSessionsForCurrentDay() -> [PomodoroSession] {
        return getSessionsForDay(Date())
    }
    
    func getSessionsForWeek(_ date: Date) -> [PomodoroSession] {
        let calendar = Calendar.current
        let weekDateComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        
        return getAllSessions().filter { session in
            let sessionComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.startTime)
            return sessionComponents.yearForWeekOfYear == weekDateComponents.yearForWeekOfYear &&
                   sessionComponents.weekOfYear == weekDateComponents.weekOfYear
        }
    }
    
    func getSessionsForCurrentWeek() -> [PomodoroSession] {
        return getSessionsForWeek(Date())
    }
    
    func getSessionsForMonth(_ date: Date) -> [PomodoroSession] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        
        return getAllSessions().filter { session in
            let sessionMonth = calendar.component(.month, from: session.startTime)
            let sessionYear = calendar.component(.year, from: session.startTime)
            return sessionMonth == month && sessionYear == year
        }
    }
    
    func getSessionsForCurrentMonth() -> [PomodoroSession] {
        return getSessionsForMonth(Date())
    }
    
    // Obtener todas las sesiones agrupadas por día
    func getAllSessionsByDay() -> [String: [PomodoroSession]] {
        let allSessions = getAllSessions()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return Dictionary(grouping: allSessions) { session in
            dateFormatter.string(from: session.startTime)
        }
    }
    
    // Obtener sesiones para un rango de fechas
    func getSessionsInRange(from startDate: Date, to endDate: Date) -> [PomodoroSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!
        
        return getAllSessions().filter { session in
            session.startTime >= startOfDay && session.startTime < endOfDay
        }
    }
    
    // Obtener fechas con sesiones (para mostrar en un calendario)
    func getDatesWithSessions() -> [Date] {
        let allSessions = getAllSessions()
        let calendar = Calendar.current
        
        let uniqueDates = Set(allSessions.map { session in
            calendar.startOfDay(for: session.startTime)
        })
        
        return Array(uniqueDates).sorted()
    }
    
    // MARK: - Stats Management
    
    func getStats() -> PomodoroStats {
        guard let data = UserDefaults.standard.data(forKey: statsKey) else { return PomodoroStats() }
        
        do {
            return try JSONDecoder().decode(PomodoroStats.self, from: data)
        } catch {
            print("Error decoding Pomodoro stats: \(error.localizedDescription)")
            return PomodoroStats()
        }
    }
    
    private func updateStats(with session: PomodoroSession) {
        var stats = getStats()
        
        if session.isCompleted {
            stats.totalSessions += 1
            stats.totalTime += session.duration
            
            // Update most productive day
            let sessions = getSessionsForDay(session.startTime)
            let count = sessions.filter { $0.isCompleted }.count
            
            if count > stats.mostProductiveDayCount {
                stats.mostProductiveDayCount = count
                
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                stats.mostProductiveDay = formatter.string(from: session.startTime)
            }
        }
        
        stats.lastUpdated = Date()
        
        do {
            let data = try JSONEncoder().encode(stats)
            UserDefaults.standard.set(data, forKey: statsKey)
        } catch {
            print("Error encoding Pomodoro stats: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Management
    
    func clearAllHistory() {
        UserDefaults.standard.removeObject(forKey: sessionsKey)
        UserDefaults.standard.removeObject(forKey: statsKey)
    }
    
    func clearHistoryOlderThan(_ date: Date) {
        let sessions = getAllSessions().filter { $0.startTime >= date }
        saveAllSessions(sessions)
        
        // Recalculate stats
        _ = PomodoroStats()
        sessions.forEach { updateStats(with: $0) }
    }
} 
