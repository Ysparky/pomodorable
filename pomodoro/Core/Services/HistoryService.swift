import Foundation
import UIKit

class HistoryService {
    static let shared = HistoryService()
    
    private let sessionsKey = "pomodoro_sessions"
    private let statsKey = "pomodoro_stats"
    private let iCloudEnabledKey = "icloud_sync_enabled"
    
    // Statistics structure to store aggregate data
    struct PomodoroStats: Codable {
        var totalSessions: Int = 0
        var totalTime: TimeInterval = 0
        var mostProductiveDay: String = ""
        var mostProductiveDayCount: Int = 0
        var lastUpdated: Date = Date()
        var lastSyncedWithCloud: Date?
    }
    
    private init() {
        // Setup observers for iCloud sync
        setupCloudSyncObservers()
    }
    
    // MARK: - iCloud Sync
    
    private func setupCloudSyncObservers() {
        // Observe when the app comes to the foreground to attempt sync
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Observe when iCloud sync is completed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudSyncCompleted),
            name: CloudKitSyncService.cloudSyncCompletedNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillEnterForeground() {
        if isCloudSyncEnabled() {
            syncWithCloud()
        }
    }
    
    @objc private func handleCloudSyncCompleted() {
        // Update the last sync timestamp
        var stats = getStats()
        stats.lastSyncedWithCloud = Date()
        saveStats(stats)
    }
    
    func isCloudSyncEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: iCloudEnabledKey)
    }
    
    func setCloudSyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: iCloudEnabledKey)
        
        if enabled {
            // If enabled, start immediate sync
            syncWithCloud()
        }
    }
    
    func syncWithCloud(completion: ((Error?) -> Void)? = nil) {
        // First check if the user has an iCloud account available
        CloudKitSyncService.shared.checkiCloudAccountStatus { [weak self] isAvailable, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error de cuenta iCloud: \(error.localizedDescription)")
                completion?(error)
                return
            }
            
            if isAvailable {
                // Fetch all iCloud sessions
                CloudKitSyncService.shared.fetchAllSessions { [weak self] cloudSessions, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error al obtener sesiones de iCloud: \(error.localizedDescription)")
                        completion?(error)
                        return
                    }
                    
                    guard let cloudSessions = cloudSessions else {
                        completion?(nil)
                        return
                    }
                    
                    // Get local sessions
                    let localSessions = self.getAllSessions()
                    
                    // Combine sessions (prefer existing locally)
                    var combinedSessions = localSessions
                    
                    // Identify new cloud sessions that don't exist locally
                    let localSessionIds = Set(localSessions.map { $0.id })
                    let newCloudSessions = cloudSessions.filter { !localSessionIds.contains($0.id) }
                    
                    // Add new cloud sessions to the local collection
                    combinedSessions.append(contentsOf: newCloudSessions)
                    
                    // Save the combined collection locally
                    self.saveAllSessions(combinedSessions)
                    
                    // Sync any new local sessions to the cloud
                    let cloudSessionIds = Set(cloudSessions.map { $0.id })
                    let newLocalSessions = localSessions.filter { !cloudSessionIds.contains($0.id) }
                    
                    if !newLocalSessions.isEmpty {
                        CloudKitSyncService.shared.saveSessions(newLocalSessions) { error in
                            if let error = error {
                                print("Error al guardar sesiones en iCloud: \(error.localizedDescription)")
                            }
                            
                            completion?(error)
                        }
                    } else {
                        completion?(nil)
                    }
                    
                    // Update stats
                    self.recalculateStats()
                }
            } else {
                print("iCloud not available")
                completion?(NSError(domain: "com.app.pomodoro", code: 1001, 
                                   userInfo: [NSLocalizedDescriptionKey: "iCloud not available"]))
            }
        }
    }
    
    // MARK: - Session Management
    
    func savePomodoroSession(_ session: PomodoroSession) {
        var sessions = getAllSessions()
        sessions.append(session)
        saveAllSessions(sessions)
        updateStats(with: session)
        
        // Sync with iCloud if enabled
        if isCloudSyncEnabled() {
            CloudKitSyncService.shared.saveSessions([session]) { error in
                if let error = error {
                    print("Error al guardar sesión en iCloud: \(error.localizedDescription)")
                }
            }
        }
        
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
    
    // Get all sessions grouped by day
    func getAllSessionsByDay() -> [String: [PomodoroSession]] {
        let allSessions = getAllSessions()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return Dictionary(grouping: allSessions) { session in
            dateFormatter.string(from: session.startTime)
        }
    }
    
    // Get sessions for a date range
    func getSessionsInRange(from startDate: Date, to endDate: Date) -> [PomodoroSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!
        
        return getAllSessions().filter { session in
            session.startTime >= startOfDay && session.startTime < endOfDay
        }
    }
    
    // Get dates with sessions (for displaying in a calendar)
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
    
    private func saveStats(_ stats: PomodoroStats) {
        do {
            let data = try JSONEncoder().encode(stats)
            UserDefaults.standard.set(data, forKey: statsKey)
        } catch {
            print("Error encoding Pomodoro stats: \(error.localizedDescription)")
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
        
        saveStats(stats)
    }
    
    // Recalculate all stats
    func recalculateStats() {
        var stats = PomodoroStats()
        let sessions = getAllSessions()
        
        for session in sessions where session.isCompleted {
            stats.totalSessions += 1
            stats.totalTime += session.duration
            
            // Find the most productive day
            let dayOfSession = getSessionsForDay(session.startTime)
            let completedCount = dayOfSession.filter { $0.isCompleted }.count
            
            if completedCount > stats.mostProductiveDayCount {
                stats.mostProductiveDayCount = completedCount
                
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                stats.mostProductiveDay = formatter.string(from: session.startTime)
            }
        }
        
        stats.lastUpdated = Date()
        saveStats(stats)
    }
    
    // MARK: - Data Management
    
    func clearAllHistory() {
        UserDefaults.standard.removeObject(forKey: sessionsKey)
        UserDefaults.standard.removeObject(forKey: statsKey)
        
        // If iCloud sync is enabled, also delete cloud data
        if isCloudSyncEnabled() {
            CloudKitSyncService.shared.deleteAllSessions { error in
                if let error = error {
                    print("Error al eliminar datos de iCloud: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearHistoryOlderThan(_ date: Date) {
        // Get all sessions
        let allSessions = getAllSessions()
        
        // Filter sessions older than the specified date
        let recentSessions = allSessions.filter { $0.startTime >= date }
        
        // Identify IDs of sessions to delete
        let sessionsToDelete = allSessions.filter { $0.startTime < date }
        let idsToDelete = sessionsToDelete.map { $0.id }
        
        // Save only recent sessions
        saveAllSessions(recentSessions)
        
        // Recalculate stats
        recalculateStats()
        
        // If iCloud sync is enabled, delete old cloud sessions
        if isCloudSyncEnabled() && !idsToDelete.isEmpty {
            CloudKitSyncService.shared.deleteSessions(ids: idsToDelete) { error in
                if let error = error {
                    print("Error al eliminar sesiones antiguas de iCloud: \(error.localizedDescription)")
                }
            }
        }
    }
} 
