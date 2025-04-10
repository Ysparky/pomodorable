import Foundation
import Combine

class TimerViewModel: ObservableObject {
    @Published var timeRemaining: Int = 25 * 60 // 25 minutes in seconds
    @Published var isRunning: Bool = false
    @Published var isWorkMode: Bool = true
    @Published var progress: Double = 1.0
    @Published var completedSessions: Int = 0
    @Published var showConfigUpdateMessage: Bool = false
    
    private var timer: AnyCancellable?
    private var configDebouncer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    // Keys to observe
    private let durationKeys = ["workTime", "shortBreakTime", "longBreakTime"]
    private let sessionsKey = "sessionsUntilLongBreak"
    
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
        // Observer for timer duration keys
        let center = NotificationCenter.default
        
        center.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    @objc private func userDefaultsDidChange(_ notification: Notification) {
        // Get the user defaults that changed
        guard let userDefaults = notification.object as? UserDefaults else { return }
        
        // Check if any of our observed keys changed
        var durationChanged = false
        var sessionsChanged = false
        
        for key in durationKeys {
            if userDefaults.object(forKey: key) != nil {
                durationChanged = true
                break
            }
        }
        
        if userDefaults.object(forKey: sessionsKey) != nil {
            sessionsChanged = true
        }
        
        // Handle the changes
        if durationChanged {
            DispatchQueue.main.async { [weak self] in
                self?.handleDurationConfigChange()
            }
        }
        
        if sessionsChanged {
            DispatchQueue.main.async { [weak self] in
                self?.handleSessionsConfigChange()
            }
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 
