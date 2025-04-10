import Foundation
import Combine

class TimerViewModel: ObservableObject {
    @Published var timeRemaining: Int = 25 * 60 // 25 minutes in seconds
    @Published var isRunning: Bool = false
    @Published var isWorkMode: Bool = true
    @Published var progress: Double = 1.0
    @Published var completedSessions: Int = 0
    @Published var showConfigUpdateMessage: Bool = false
    
    // Store the initial total time for the current session to calculate progress
    private var currentSessionTotalTime: Int = 25 * 60
    
    private var timer: AnyCancellable?
    private var configDebouncer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    // Keys to observe
    private let durationKeys = ["workTime", "shortBreakTime", "longBreakTime"]
    private let sessionsKey = "sessionsUntilLongBreak"
    private let otherKeys = ["soundEnabled", "notificationsEnabled", "autoStartBreaks", "autoStartPomodoros"]
    
    // Notification names
    private let durationChangedNotification = Notification.Name("DurationSettingsChanged")
    private let sessionsChangedNotification = Notification.Name("SessionsSettingsChanged")
    
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
        
        // Observe configuration changes
        setupConfigObserver()
    }
    
    private func setupConfigObserver() {
        // Set up notification center observers
        let center = NotificationCenter.default
        
        // Remove previous observers if they exist
        center.removeObserver(self)
        
        // Add observers for our specific notifications
        center.addObserver(self, selector: #selector(handleDurationSettingsChanged), name: durationChangedNotification, object: nil)
        center.addObserver(self, selector: #selector(handleSessionsSettingsChanged), name: sessionsChangedNotification, object: nil)
    }
    
    @objc private func handleDurationSettingsChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.handleDurationConfigChange()
        }
    }
    
    @objc private func handleSessionsSettingsChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.handleSessionsConfigChange()
        }
    }
    
    private func handleDurationConfigChange() {
        if isRunning {
            // If timer is running, show message that changes will apply next session
            self.showConfigUpdateMessage = true
            
            // Auto-hide the message after 3 seconds
            self.configDebouncer?.cancel()
            self.configDebouncer = Timer.publish(every: 3, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.showConfigUpdateMessage = false
                }
            // Do not update progress while session is running
        } else {
            // If timer is not running, update immediately
            self.updateTimerWithNewConfig()
        }
    }
    
    private func handleSessionsConfigChange() {
        // Only update the configuration without showing a message
        if !isRunning {
            self.updateTimerWithNewConfig()
        }
    }
    
    func dismissConfigMessage() {
        showConfigUpdateMessage = false
    }
    
    private func updateTimerWithNewConfig() {
        // Only update if timer is not running
        guard !isRunning else { return }
        
        // Update time remaining based on current mode
        timeRemaining = isWorkMode ? getWorkTime() : getBreakTime()
        
        // Update the current session total time to match the new settings
        currentSessionTotalTime = timeRemaining
        
        // Update progress
        updateProgress()
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
            // Store the total time when starting the timer
            currentSessionTotalTime = isWorkMode ? getWorkTime() : getBreakTime()
            startTimer()
        } else {
            timer?.cancel()
        }
    }
    
    func resetTimer() {
        timer?.cancel()
        isRunning = false
        isWorkMode = true
        timeRemaining = getWorkTime()
        // Reset the current session total time
        currentSessionTotalTime = timeRemaining
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
        // Use the stored total time for the current session rather than recalculating
        // This ensures that changes to settings don't affect the progress display mid-session
        progress = Double(timeRemaining) / Double(currentSessionTotalTime)
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
        // Update the current session total time for the new session
        currentSessionTotalTime = timeRemaining
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
    
    deinit {
        // Only remove observers from NotificationCenter
        NotificationCenter.default.removeObserver(self)
    }
} 
