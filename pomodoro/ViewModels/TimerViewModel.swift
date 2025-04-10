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
    private var configObserver: AnyCancellable?
    private var configDebouncer: AnyCancellable?
    
    // Default values
    private let defaultWorkTime: Int = 25 * 60
    private let defaultShortBreakTime: Int = 5 * 60
    private let defaultLongBreakTime: Int = 15 * 60
    private let defaultSessionsUntilLongBreak: Int = 4
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Request notification permissions when the app starts
        NotificationService.shared.requestAuthorization()
        // Initialize timer with current settings
        resetTimer()
        
        // Observe configuration changes
        setupConfigObserver()
    }
    
    private func setupConfigObserver() {
        // Create a publisher that only triggers for timer duration changes
        let _: () = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .compactMap { notification -> (String, Double)? in
                guard let key = notification.userInfo?["key"] as? String,
                      let value = UserDefaults.standard.object(forKey: key) as? Double,
                      ["workTime", "shortBreakTime", "longBreakTime"].contains(key) else {
                    return nil
                }
                return (key, value)
            }
            .receive(on: DispatchQueue.main)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleConfigChange()
            }
            .store(in: &cancellables)
        
        // Observe sessions until long break separately
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .compactMap { notification -> Int? in
                guard let key = notification.userInfo?["key"] as? String,
                      key == "sessionsUntilLongBreak",
                      let value = UserDefaults.standard.object(forKey: key) as? Int else {
                    return nil
                }
                return value
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSessionsConfigChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleConfigChange() {
        if isRunning {
            // If timer is running, show message that changes will apply next session
            showConfigUpdateMessage = true
            
            // Auto-hide the message after 3 seconds
            configDebouncer?.cancel()
            configDebouncer = Timer.publish(every: 3, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.showConfigUpdateMessage = false
                }
        } else {
            // If timer is not running, update immediately
            updateTimerWithNewConfig()
        }
    }
    
    private func handleSessionsConfigChange() {
        // Only update the configuration without showing a message
        if !isRunning {
            updateTimerWithNewConfig()
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
} 
