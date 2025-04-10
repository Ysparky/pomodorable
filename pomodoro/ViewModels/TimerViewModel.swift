import Foundation
import Combine

class TimerViewModel: ObservableObject {
    @Published var timeRemaining: Int = 25 * 60 // 25 minutes in seconds
    @Published var isRunning: Bool = false
    @Published var isWorkMode: Bool = true
    @Published var progress: Double = 1.0
    
    private var timer: AnyCancellable?
    private let workTime: Int = 25 * 60
    private let shortBreakTime: Int = 5 * 60
    private let longBreakTime: Int = 15 * 60
    
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
        timeRemaining = isWorkMode ? workTime : shortBreakTime
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
        let totalTime = isWorkMode ? workTime : shortBreakTime
        progress = Double(timeRemaining) / Double(totalTime)
    }
    
    private func switchMode() {
        isWorkMode.toggle()
        timeRemaining = isWorkMode ? workTime : shortBreakTime
        progress = 1.0
        // TODO: Add notification when mode changes
    }
} 