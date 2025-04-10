import Foundation
import Combine
import UIKit

class TimerViewModel: ObservableObject {
    @Published var timeRemaining: Int = 25 * 60 // 25 minutes in seconds
    @Published var isRunning: Bool = false
    @Published var isWorkMode: Bool = true
    @Published var progress: Double = 1.0
    @Published var completedSessions: Int = 0
    @Published var showConfigUpdateMessage: Bool = false
    
    // Store the initial total time for the current session to calculate progress
    private var currentSessionTotalTime: Int = 25 * 60
    
    // Variables for handling time with greater precision
    private var timerStartDate: Date?
    private var accumulatedTime: TimeInterval = 0
    
    private var timer: AnyCancellable?
    private var configDebouncer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    // Variables for handling background state
    private var backgroundDate: Date?
    
    // Settings view model for accessing user preferences
    private let settingsViewModel = SettingsViewModel()
    
    init() {
        // Request notification permissions when the app starts
        NotificationService.shared.requestAuthorization()
        
        // Initialize timer with current settings
        resetTimer()
        
        // Observe configuration changes
        setupConfigObserver()
        
        // Observe application state changes
        setupAppStateObservers()
    }
    
    deinit {
        // Only remove observers from NotificationCenter
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupAppStateObservers() {
        // Add observers for when the app enters background and returns to foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidEnterBackground() {
        // Save current time when the app enters background
        if isRunning {
            // Store the elapsed time up to this moment
            if let startDate = timerStartDate {
                accumulatedTime += -startDate.timeIntervalSinceNow
                timerStartDate = nil
            }
            
            backgroundDate = Date()
            // Cancel the timer while in background
            timer?.cancel()
            
            // Schedule a local notification for when the timer ends
            // This will serve as a backup for the date-based calculation
            NotificationService.shared.scheduleTimerEndNotification(
                timeRemaining: timeRemaining,
                isWorkMode: isWorkMode
            )
        }
    }
    
    @objc private func handleAppWillEnterForeground() {
        // Cancel pending notifications since the app is back in foreground
        NotificationService.shared.cancelPendingTimerNotifications()
        
        // Calculate elapsed time when the app returns to foreground
        if isRunning, let backgroundDate = backgroundDate {
            // Calculate with precision the elapsed time (including fractions of seconds)
            let elapsedTimeInterval = -backgroundDate.timeIntervalSinceNow
            
            // Add the elapsed time in background to the accumulated time
            accumulatedTime += elapsedTimeInterval
            
            // Calculate the new remaining time
            let newTimeRemaining = max(0, Double(currentSessionTotalTime) - accumulatedTime)
            timeRemaining = Int(round(newTimeRemaining))
            
            // If the time finished while in background
            if timeRemaining <= 0 {
                timeRemaining = 0
                // Switch mode in the next timer cycle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.switchMode()
                }
            } else {
                // Update progress
                updateProgress()
                
                // Restart the timer if active
                startTimer()
            }
            
            // Reset the background date
            self.backgroundDate = nil
        }
    }
    
    private func setupConfigObserver() {
        // Set up notification center observers
        let center = NotificationCenter.default
        
        // Remove previous observers if they exist
        center.removeObserver(self, name: SettingsViewModel.durationChangedNotification, object: nil)
        center.removeObserver(self, name: SettingsViewModel.sessionsChangedNotification, object: nil)
        
        // Add observers for our specific notifications
        center.addObserver(self, selector: #selector(handleDurationSettingsChanged), name: SettingsViewModel.durationChangedNotification, object: nil)
        center.addObserver(self, selector: #selector(handleSessionsSettingsChanged), name: SettingsViewModel.sessionsChangedNotification, object: nil)
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
            
            // Cancel any previous notification
            NotificationService.shared.cancelPendingTimerNotifications()
        } else {
            pauseTimer()
            
            // Cancel scheduled notification when manually paused
            NotificationService.shared.cancelPendingTimerNotifications()
        }
    }
    
    func resetTimer() {
        // Stop the current timer
        timer?.cancel()
        
        // Reset the state
        isRunning = false
        isWorkMode = true
        
        // Reset all time-related values
        timeRemaining = getWorkTime()
        currentSessionTotalTime = timeRemaining
        accumulatedTime = 0
        timerStartDate = nil
        backgroundDate = nil
        
        // Update progress
        progress = 1.0
    }
    
    private func pauseTimer() {
        // Save the elapsed time up to this moment with precision
        if let startDate = timerStartDate {
            let elapsed = -startDate.timeIntervalSinceNow
            accumulatedTime += elapsed
            timerStartDate = nil
            
            // Update remaining time with precision to ensure it shows the correct value
            let newTimeRemaining = max(0, Double(currentSessionTotalTime) - accumulatedTime)
            timeRemaining = Int(round(newTimeRemaining))
            updateProgress()
        }
        
        // Cancel the timer
        timer?.cancel()
    }
    
    private func startTimer() {
        // Cancel any existing timer
        timer?.cancel()
        
        // Set the timer start date
        timerStartDate = Date()
        
        // Configure the timer to update the UI every 0.1 seconds for greater smoothness
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Calculate the total elapsed time (accumulated + current)
                let currentElapsed = self.timerStartDate != nil ? -self.timerStartDate!.timeIntervalSinceNow : 0
                let totalElapsed = self.accumulatedTime + currentElapsed
                
                // Calculate the new remaining time (with decimal precision)
                let newTimeRemaining = max(0, Double(self.currentSessionTotalTime) - totalElapsed)
                
                // Round to show only whole seconds
                let newTimeRemainingInt = Int(round(newTimeRemaining))
                
                // Update only if there's a change to avoid unnecessary updates
                if newTimeRemainingInt != self.timeRemaining {
                    self.timeRemaining = newTimeRemainingInt
                    self.updateProgress()
                    
                    // If we reach zero, switch mode
                    if self.timeRemaining <= 0 {
                        self.pauseTimer()
                        self.accumulatedTime = 0
                        self.switchMode()
                    }
                }
            }
    }
    
    private func updateProgress() {
        // Use the stored total time for the current session rather than recalculating
        // This ensures that changes to settings don't affect the progress display mid-session
        progress = Double(timeRemaining) / Double(currentSessionTotalTime)
    }
    
    private func switchMode() {
        // Cancel pending notifications when switching modes
        NotificationService.shared.cancelPendingTimerNotifications()
        
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
        
        // Reset the accumulated time for the new session
        accumulatedTime = 0
        timerStartDate = nil
        
        // Auto-start next timer if enabled
        if shouldAutoStartNextTimer() {
            isRunning = true
            startTimer()
        } else {
            isRunning = false
        }
    }
    
    // MARK: - Settings Helpers
    
    private func getWorkTime() -> Int {
        settingsViewModel.getWorkTime()
    }
    
    private func getBreakTime() -> Int {
        let shouldTakeLongBreak = completedSessions > 0 && completedSessions % settingsViewModel.getSessionsUntilLongBreak() == 0
        return settingsViewModel.getBreakTime(shouldTakeLongBreak: shouldTakeLongBreak)
    }
    
    private func shouldAutoStartNextTimer() -> Bool {
        if isWorkMode {
            return settingsViewModel.shouldAutoStartPomodoros()
        } else {
            return settingsViewModel.shouldAutoStartBreaks()
        }
    }
} 
