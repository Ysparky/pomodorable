import Foundation

struct PomodoroSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let isCompleted: Bool
    
    init(id: UUID = UUID(), startTime: Date, endTime: Date, duration: TimeInterval, isCompleted: Bool) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.isCompleted = isCompleted
    }
    
    // Computed properties for easy date grouping
    var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startTime)
    }
    
    var weekString: String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: startTime)
        let year = calendar.component(.year, from: startTime)
        return "\(year)-W\(weekOfYear)"
    }
    
    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: startTime)
    }
    
    // Formatted time string
    var durationString: String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
    
    // Formatted date string
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    // Time of day string
    var timeOfDayString: String {
        let hour = Calendar.current.component(.hour, from: startTime)
        
        switch hour {
        case 5..<12:
            return "Morning"
        case 12..<17:
            return "Afternoon"
        case 17..<21:
            return "Evening"
        default:
            return "Night"
        }
    }
} 