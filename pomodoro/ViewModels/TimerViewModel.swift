import Foundation
import Combine

class TimerViewModel: ObservableObject {
    @Published var timeRemaining: Int = 25 * 60 // 25 minutes in seconds
    @Published var isRunning: Bool = false
    @Published var isWorkMode: Bool = true
    @Published var progress: Double = 1.0
    @Published var completedSessions: Int = 0
    
    private var timer: AnyCancellable?
    
    // Default values
    private let defaultWorkTime: Int = 25 * 60
    private let defaultShortBreakTime: Int = 5 * 60
    private let defaultLongBreakTime: Int = 15 * 60
    private let defaultSessionsUntilLongBreak: Int = 4
    
    init() {
        // Request notification permissions when the app starts
        NotificationService.shared.requestAuthorization()
        // Initialize timer with current settings
        resetTimer()
    }
    
    var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var modeText: String {
        isWorkMode ? "Focus Time" : "Break Time"
    }
    
    func toggleTimer() {
        isRunning.toggle()
        if isRunning {
            startTimer()
        } else {
            timer?.cancel()
        }
    }
    
    func resetTimer() {
        timer?.cancel()
        isRunning = false
        timeRemaining = isWorkMode ? getWorkTime() : getBreakTime()
        progress = 1.0
    }
    
    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                    self.updateProgress()
                } else {
                    self.switchMode()
                }
            }
    }
    
    private func updateProgress() {
        let totalTime = isWorkMode ? getWorkTime() : getBreakTime()
        progress = Double(timeRemaining) / Double(totalTime)
    }
    
    private func switchMode() {
        if isWorkMode {
            completedSessions += 1
            NotificationService.shared.scheduleNotification(for: .break_)
        } else {
            NotificationService.shared.scheduleNotification(for: .work)
        }
        
        isWorkMode.toggle()
        timeRemaining = isWorkMode ? getWorkTime() : getBreakTime()
        progress = 1.0
        
        // Auto-start next timer if enabled
        if shouldAutoStartNextTimer() {
            isRunning = true
            startTimer()
        }
    }
    
    // MARK: - Settings Helpers
    
    private func getWorkTime() -> Int {
        Int(UserDefaults.standard.double(forKey: "workTime") * 60)
    }
    
    private func getBreakTime() -> Int {
        if shouldTakeLongBreak() {
            return Int(UserDefaults.standard.double(forKey: "longBreakTime") * 60)
        } else {
            return Int(UserDefaults.standard.double(forKey: "shortBreakTime") * 60)
        }
    }
    
    private func shouldTakeLongBreak() -> Bool {
        let sessionsUntilLongBreak = UserDefaults.standard.integer(forKey: "sessionsUntilLongBreak")
        return completedSessions > 0 && completedSessions % sessionsUntilLongBreak == 0
    }
    
    private func shouldAutoStartNextTimer() -> Bool {
        if isWorkMode {
            return UserDefaults.standard.bool(forKey: "autoStartPomodoros")
        } else {
            return UserDefaults.standard.bool(forKey: "autoStartBreaks")
        }
    }
} 