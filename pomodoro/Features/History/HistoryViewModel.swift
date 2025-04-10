import Foundation
import Combine
import SwiftUI

class HistoryViewModel: ObservableObject {
    @Published var dailySessions: [PomodoroSession] = []
    @Published var weeklySessions: [PomodoroSession] = []
    @Published var monthlySessions: [PomodoroSession] = []
    @Published var stats: HistoryService.PomodoroStats = HistoryService.PomodoroStats()
    
    @Published var selectedTimeframe: Timeframe = .daily
    @Published var selectedDate: Date = Date()
    @Published var datesWithSessions: [Date] = []
    @Published var isCustomDateSelected: Bool = false
    @Published var dateTitle: String = "Hoy"
    
    // Properties for iCloud sync
    @Published var isCloudSyncEnabled: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case daily
        case weekly
        case monthly
        
        var id: String { self.rawValue }
        
        var localizedName: String {
            switch self {
            case .daily:
                return "today".localized
            case .weekly:
                return "this_week".localized
            case .monthly:
                return "this_month".localized
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load sync status
        isCloudSyncEnabled = HistoryService.shared.isCloudSyncEnabled()
        
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
        
        // Observer for when iCloud sync is completed
        NotificationCenter.default.publisher(for: CloudKitSyncService.cloudSyncCompletedNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshHistory()
                self?.isSyncing = false
                self?.lastSyncDate = Date()
                self?.syncError = nil
            }
            .store(in: &cancellables)
        
        // Create timer to periodically refresh the data every minute
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshHistory()
            }
            .store(in: &cancellables)
            
        // Setup timeframe selection observation
        $selectedTimeframe
            .sink { [weak self] timeframe in
                self?.resetCustomDateSelection()
                self?.refreshHistory()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - iCloud Sync
    
    func toggleCloudSync() {
        isCloudSyncEnabled.toggle()
        HistoryService.shared.setCloudSyncEnabled(isCloudSyncEnabled)
        
        if isCloudSyncEnabled {
            syncWithCloud()
        }
    }
    
    func syncWithCloud() {
        guard isCloudSyncEnabled else {
            syncError = "cloud_sync_not_enabled".localized
            return
        }
        
        isSyncing = true
        syncError = nil
        
        HistoryService.shared.syncWithCloud { [weak self] error in
            DispatchQueue.main.async {
                self?.isSyncing = false
                
                if let error = error {
                    self?.syncError = error.localizedDescription
                } else {
                    self?.lastSyncDate = Date()
                    self?.refreshHistory()
                }
            }
        }
    }
    
    func refreshHistory() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.isCustomDateSelected {
                // If there is a specific date selected, load data for that date
                self.loadHistoryForSelectedDate()
            } else {
                // Otherwise, load data for the selected timeframe
                self.dailySessions = HistoryService.shared.getSessionsForCurrentDay()
                self.weeklySessions = HistoryService.shared.getSessionsForCurrentWeek()
                self.monthlySessions = HistoryService.shared.getSessionsForCurrentMonth()
                self.stats = HistoryService.shared.getStats()
                
                // Update last sync date
                self.lastSyncDate = self.stats.lastSyncedWithCloud
                
                // Update date title
                self.updateDateTitle()
            }
            
            // Force UI update by triggering objectWillChange
            self.objectWillChange.send()
        }
    }
    
    func loadDatesWithSessions() {
        self.datesWithSessions = HistoryService.shared.getDatesWithSessions()
    }
    
    func selectSpecificDate(_ date: Date) {
        self.selectedDate = date
        self.isCustomDateSelected = true
        
        // Load data only for the selected date
        self.dailySessions = HistoryService.shared.getSessionsForDay(date)
        
        // Update date title
        updateDateTitle()
        
        // Notify the UI
        self.objectWillChange.send()
    }
    
    func resetToCurrentDay() {
        selectedDate = Date()
        selectedTimeframe = .daily
        isCustomDateSelected = false
        refreshHistory()
    }
    
    func resetToCurrentWeek() {
        selectedDate = Date()
        selectedTimeframe = .weekly
        isCustomDateSelected = false
        refreshHistory()
    }
    
    func resetToCurrentMonth() {
        selectedDate = Date()
        selectedTimeframe = .monthly
        isCustomDateSelected = false
        refreshHistory()
    }
    
    private func resetCustomDateSelection() {
        if isCustomDateSelected {
            isCustomDateSelected = false
            selectedDate = Date()
            updateDateTitle()
        }
    }
    
    private func loadHistoryForSelectedDate() {
        if isCustomDateSelected {
            switch selectedTimeframe {
            case .daily:
                dailySessions = HistoryService.shared.getSessionsForDay(selectedDate)
                weeklySessions = HistoryService.shared.getSessionsForWeek(selectedDate)
                monthlySessions = HistoryService.shared.getSessionsForMonth(selectedDate)
            case .weekly:
                let calendar = Calendar.current
                let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
                let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? selectedDate
                dailySessions = HistoryService.shared.getSessionsForDay(selectedDate)
                weeklySessions = HistoryService.shared.getSessionsInRange(from: startOfWeek, to: endOfWeek)
                monthlySessions = HistoryService.shared.getSessionsForMonth(selectedDate)
            case .monthly:
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month], from: selectedDate)
                if let startOfMonth = calendar.date(from: components),
                   let range = calendar.range(of: .day, in: .month, for: startOfMonth),
                   let endOfMonth = calendar.date(byAdding: .day, value: range.count - 1, to: startOfMonth) {
                    dailySessions = HistoryService.shared.getSessionsForDay(selectedDate)
                    weeklySessions = HistoryService.shared.getSessionsForWeek(selectedDate)
                    monthlySessions = HistoryService.shared.getSessionsInRange(from: startOfMonth, to: endOfMonth)
                }
            }
        } else {
            // If there is no specific date, use the current date
            dailySessions = HistoryService.shared.getSessionsForCurrentDay()
            weeklySessions = HistoryService.shared.getSessionsForCurrentWeek()
            monthlySessions = HistoryService.shared.getSessionsForCurrentMonth()
        }
    }
    
    private func updateDateTitle() {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        let calendar = Calendar.current
        
        if calendar.isDateInToday(selectedDate) {
            dateTitle = "today".localized
        } else if calendar.isDateInYesterday(selectedDate) {
            dateTitle = "yesterday".localized
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            dateTitle = formatter.string(from: selectedDate)
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
    
    // MARK: - Formatters
    
    var lastSyncFormatted: String {
        guard let lastSync = lastSyncDate else {
            return "never".localized
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
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
    
    // Returns productivity statistics by day of the week (to identify weekly patterns)
    var productivityByDayOfWeek: [String: (sessions: Int, minutes: Int)] {
        let completedSessions = monthlySessions.filter { $0.isCompleted }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        // Initialize dictionary with all days of the week
        var result: [String: (sessions: Int, minutes: Int)] = [:]
        
        // Use shortWeekdaySymbols to ensure all days are included
        for (_, symbol) in formatter.shortWeekdaySymbols.enumerated() {
            result[symbol] = (0, 0)
        }
        
        // Grouping by day of the week
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
    
    // Returns the average session duration by day
    var averageSessionDurationByDay: [String: Double] {
        let sessionsByDay = Dictionary(grouping: sessionsForSelectedTimeframe.filter { $0.isCompleted }) { $0.dayString }
        
        return sessionsByDay.mapValues { sessions in
            let totalDuration = sessions.reduce(0) { $0 + $1.duration }
            return totalDuration / Double(sessions.count) / 60 // Convertir a minutos
        }
    }
    
    // Returns the number of completed sessions by day for a range of dates
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
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        // Adjust index (weekday of Calendar: 1=Sunday, 2=Monday, etc.)
        // For DateFormatter.shortWeekdaySymbols: 0=Sunday, 1=Monday, etc. (in US locale)
        let index = weekday - 1
        
        if index >= 0 && index < formatter.shortWeekdaySymbols.count {
            return formatter.shortWeekdaySymbols[index]
        }
        return ""
    }
    
    // Gets the full day name according to the current locale
    private func getFullDayOfWeekName(shortName: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        // Try to find the index of the short name in shortWeekdaySymbols
        if let index = formatter.shortWeekdaySymbols.firstIndex(of: shortName),
           index < formatter.weekdaySymbols.count {
            return formatter.weekdaySymbols[index]
        }
        
        return shortName
    }
    
    // Returns the most productive day of the week (with the most number of completed sessions)
    func getMostProductiveDayOfWeek() -> (String, Int)? {
        let completedSessions = weeklySessions.filter { $0.isCompleted }
        
        // If there are no completed sessions, return nil
        if completedSessions.isEmpty {
            return nil
        }
        
        // Group by day of the week
        let calendar = Calendar.current
        var sessionsByDayOfWeek: [String: Int] = [:]
        
        for session in completedSessions {
            let weekday = calendar.component(.weekday, from: session.startTime)
            let dayName = getDayOfWeekName(weekday: weekday)
            
            sessionsByDayOfWeek[dayName, default: 0] += 1
        }
        
        // Find the day with the most sessions
        if let mostProductiveDay = sessionsByDayOfWeek.max(by: { $0.value < $1.value }) {
            let fullDayName = getFullDayOfWeekName(shortName: mostProductiveDay.key)
            return (fullDayName, mostProductiveDay.value)
        }
        
        return nil
    }
    
    // Returns the most productive date of the month (with the most number of completed sessions)
    func getMostProductiveDateOfMonth() -> (Date, Int)? {
        let completedSessions = monthlySessions.filter { $0.isCompleted }
        
        // If there are no completed sessions, return nil
        if completedSessions.isEmpty {
            return nil
        }
        
        // Group by date (specific day)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var sessionsByDate: [String: (date: Date, count: Int)] = [:]
        
        for session in completedSessions {
            let dateString = dateFormatter.string(from: session.startTime)
            
            if let existingData = sessionsByDate[dateString] {
                sessionsByDate[dateString] = (existingData.date, existingData.count + 1)
            } else {
                // Normalize the date to remove the time
                let normalizedDate = Calendar.current.startOfDay(for: session.startTime)
                sessionsByDate[dateString] = (normalizedDate, 1)
            }
        }
        
        // Find the date with the most sessions
        if let mostProductiveDate = sessionsByDate.max(by: { $0.value.count < $1.value.count }) {
            return (mostProductiveDate.value.date, mostProductiveDate.value.count)
        }
        
        return nil
    }
    
    // MARK: - Computed Properties
    
    var totalSessionsForSelectedDay: Int {
        return dailySessions.filter { $0.isCompleted }.count
    }
    
    var totalMinutesForSelectedDay: Int {
        let sessions = dailySessions.filter { $0.isCompleted }
        let totalSeconds = sessions.reduce(0) { $0 + $1.duration }
        return Int(totalSeconds / 60)
    }
    
    var sessionsForSelectedDay: [PomodoroSession] {
        return dailySessions
    }
    
    // Returns the number of completed sessions for the selected day
    var selectedDaySessionsCount: Int {
        return dailySessions.filter { $0.isCompleted }.count
    }
    
    // MARK: - Helper Functions
    
    // Returns the most productive time of the selected day
    var mostProductiveTimeOfSelectedDay: String? {
        let completedSessions = dailySessions.filter { $0.isCompleted }
        guard !completedSessions.isEmpty else { return nil }
        
        let groupedByTime = Dictionary(grouping: completedSessions) { $0.timeOfDayString }
        
        let mostProductiveTime = groupedByTime.max { a, b in
            return a.value.count < b.value.count
        }
        
        return mostProductiveTime?.key
    }
}

// Notification for when a new Pomodoro session is added
extension Notification.Name {
    static let newPomodoroSessionAdded = Notification.Name("newPomodoroSessionAdded")
    static let historyTabSelected = Notification.Name("historyTabSelected")
} 
