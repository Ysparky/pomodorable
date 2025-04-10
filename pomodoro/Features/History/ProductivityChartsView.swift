import SwiftUI
import Charts

struct ProductivityChartsView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var selectedChartType: ChartType = .daily
    
    enum ChartType: String, CaseIterable, Identifiable {
        case daily
        case hourly
        case trend
        case weekly
        
        var id: String { self.rawValue }
        
        var localizedName: String {
            switch self {
            case .daily:
                return "day_distribution".localized
            case .hourly:
                return "time_of_day".localized
            case .trend:
                return "monthly_trend".localized
            case .weekly:
                return "weekday_distribution".localized
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Chart type selector
            Picker("stats".localized, selection: $selectedChartType) {
                ForEach(ChartType.allCases) { type in
                    Text(type.localizedName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 0)
            .padding(.bottom, 8)
            
            // Chart display
            switch selectedChartType {
            case .daily:
                DailySessionsChart(sessions: viewModel.sessionsForSelectedDay)
            case .hourly:
                HourlyDistributionChart(sessions: viewModel.sessionsForSelectedDay)
            case .trend:
                ProductivityTrendChart(sessions: viewModel.sessionsForSelectedDay)
            case .weekly:
                WeekdayProductivityChart(viewModel: viewModel)
            }
        }
    }
}

// Bar chart that shows sessions by day
struct DailySessionsChart: View {
    let sessions: [PomodoroSession]
    
    var sessionsPerDay: [DailySessionCount] {
        let sessionsByDay = Dictionary(grouping: sessions) { $0.dayString }
        return sessionsByDay.map { (day, daySessions) in
            let completedCount = daySessions.filter { $0.isCompleted }.count
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let date = formatter.date(from: day) ?? Date()
            
            return DailySessionCount(
                date: date,
                day: formatDayName(date),
                completedSessions: completedCount
            )
        }
        .sorted { $0.date < $1.date }
    }
    
    private func formatDayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("sessions".localized)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            
            if #available(iOS 16.0, *) {
                Chart(sessionsPerDay) { dayData in
                    BarMark(
                        x: .value("day".localized, dayData.day),
                        y: .value("sessions".localized, dayData.completedSessions)
                    )
                    .foregroundStyle(Color.green.gradient)
                }
                .frame(height: 220)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            } else {
                // Fallback for iOS 15 or earlier
                Text("chart_ios16_required".localized)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// Circular chart that shows session distribution by hour of the day
struct HourlyDistributionChart: View {
    let sessions: [PomodoroSession]
    
    var sessionsByTimeOfDay: [TimeOfDayData] {
        let completedSessions = sessions.filter { $0.isCompleted }
        let groupedByTime = Dictionary(grouping: completedSessions) { $0.timeOfDayString }
        
        let result = [
            TimeOfDayData(timeOfDay: "morning", label: "morning".localized, count: groupedByTime["Morning"]?.count ?? 0),
            TimeOfDayData(timeOfDay: "afternoon", label: "afternoon".localized, count: groupedByTime["Afternoon"]?.count ?? 0),
            TimeOfDayData(timeOfDay: "evening", label: "evening".localized, count: groupedByTime["Evening"]?.count ?? 0),
            TimeOfDayData(timeOfDay: "night", label: "night".localized, count: groupedByTime["Night"]?.count ?? 0)
        ]
        
        return result.filter { $0.count > 0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("time_of_day".localized)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            
            if #available(iOS 16.0, *) {
                Chart(sessionsByTimeOfDay) { timeData in
                    SectorMark(
                        angle: .value("sessions".localized, timeData.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("time_of_day".localized, timeData.label))
                    .annotation(position: .overlay) {
                        if timeData.count > 0 {
                            Text("\(timeData.count)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                        }
                    }
                }
                .frame(height: 220)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
            } else {
                // Fallback for iOS 15 or earlier
                Text("chart_ios16_required".localized)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// Line chart that shows productivity trend
struct ProductivityTrendChart: View {
    let sessions: [PomodoroSession]
    
    var productivityTrend: [ProductivityTrendPoint] {
        // Group sessions by day
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let sessionsByDay = Dictionary(grouping: sessions) { session in
            dateFormatter.string(from: session.startTime)
        }
        
        return sessionsByDay.map { (dayString, daySessions) in
            let completedCount = daySessions.filter { $0.isCompleted }.count
            let totalMinutes = daySessions.filter { $0.isCompleted }.reduce(0) { $0 + Int($1.duration / 60) }
            let date = dateFormatter.date(from: dayString) ?? Date()
            
            return ProductivityTrendPoint(
                date: date,
                day: formatShortDate(date),
                completedSessions: completedCount,
                totalMinutes: totalMinutes
            )
        }
        .sorted { $0.date < $1.date }
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("monthly_trend".localized)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            
            if #available(iOS 16.0, *) {
                Chart(productivityTrend) { dataPoint in
                    LineMark(
                        x: .value("day".localized, dataPoint.day),
                        y: .value("minutes".localized, dataPoint.totalMinutes)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    
                    PointMark(
                        x: .value("day".localized, dataPoint.day),
                        y: .value("minutes".localized, dataPoint.totalMinutes)
                    )
                    .foregroundStyle(Color.blue)
                }
                .frame(height: 220)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            } else {
                // Fallback for iOS 15 or earlier
                Text("chart_ios16_required".localized)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// Chart that shows productivity by day of the week
struct WeekdayProductivityChart: View {
    @ObservedObject var viewModel: HistoryViewModel
    
    var weekdayData: [WeekdayProductivityData] {
        // Get productivity data by day of the week
        let productivityData = viewModel.productivityByDayOfWeek
        
        // Use DateFormatter to get the weekday names according to the current locale
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        // Sort according to the first weekday of the calendar
        let calendar = Calendar.current
        
        // Ensure we have weekday symbols (not optional)
        guard let weekdaySymbols = formatter.shortWeekdaySymbols else {
            // Fallback to default days if no symbols are available
            return []
        }
        
        // Create a mutable copy of the symbols array
        var orderedSymbols = weekdaySymbols
        
        // If the week starts on Sunday (US) but we want to show Monday first
        // Or vice versa according to system configuration
        let firstWeekdayIndex = (calendar.firstWeekday - 1)  // 0-based
        if firstWeekdayIndex > 0 && firstWeekdayIndex < orderedSymbols.count {
            // Reorder the days starting with the first day of the week according to the calendar
            let firstPart = Array(orderedSymbols.prefix(firstWeekdayIndex))
            orderedSymbols.removeFirst(firstWeekdayIndex)
            orderedSymbols.append(contentsOf: firstPart)
        }
        
        // Convert to array for the chart
        return orderedSymbols.map { day in
            // Search for data for this day - default if not exists
            let data = productivityData[day] ?? (sessions: 0, minutes: 0)
            return WeekdayProductivityData(
                day: day,
                sessions: data.sessions,
                minutes: data.minutes
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("weekday_distribution".localized)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(weekdayData) { item in
                        BarMark(
                            x: .value("day".localized, item.day),
                            y: .value("sessions".localized, item.sessions)
                        )
                        .foregroundStyle(Color.green.gradient)
                    }
                    
                    ForEach(weekdayData) { item in
                        LineMark(
                            x: .value("day".localized, item.day),
                            y: .value("minutes".localized, item.minutes)
                        )
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .symbol() {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .frame(height: 220)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartForegroundStyleScale([
                    "sessions".localized: Color.green,
                    "minutes".localized: Color.blue
                ])
                .chartLegend(position: .bottom, alignment: .center)
            } else {
                // Fallback for iOS 15 or earlier
                Text("chart_ios16_required".localized)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.secondarySystemGroupedBackground))
            }
            
            // Productivity analysis
            VStack(alignment: .leading, spacing: 8) {
                Text("stats".localized + ":")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text(getMostProductiveDay())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func getMostProductiveDay() -> String {
        let data = weekdayData
        
        if let mostSessions = data.max(by: { $0.sessions < $1.sessions }) {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            
            // Get the arrays of symbols (not optional)
            guard let shortSymbols = formatter.shortWeekdaySymbols,
                  let fullSymbols = formatter.weekdaySymbols else {
                // If we can't get the symbols, use the abbreviated day directly
                return String(format: "most_productive_day_message".localized, 
                              mostSessions.day, 
                              mostSessions.sessions)
            }
            
            // Try to find the index of the abbreviated day
            if let dayIndex = shortSymbols.firstIndex(of: mostSessions.day),
               dayIndex < fullSymbols.count {
                let fullDayName = fullSymbols[dayIndex]
                return String(format: "most_productive_day_message".localized, 
                              fullDayName, 
                              mostSessions.sessions)
            } else {
                // If not found, use the abbreviated name directly
                return String(format: "most_productive_day_message".localized, 
                              mostSessions.day, 
                              mostSessions.sessions)
            }
        } else {
            return "no_productivity_data".localized
        }
    }
}

// Data models for the charts
struct DailySessionCount: Identifiable {
    let id = UUID()
    let date: Date
    let day: String
    let completedSessions: Int
}

struct TimeOfDayData: Identifiable {
    let id = UUID()
    let timeOfDay: String
    let label: String
    let count: Int
}

struct ProductivityTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let day: String
    let completedSessions: Int
    let totalMinutes: Int
}

struct WeekdayProductivityData: Identifiable {
    let id = UUID()
    let day: String
    let sessions: Int
    let minutes: Int
}

struct ProductivityChartsView_Previews: PreviewProvider {
    static var previews: some View {
        ProductivityChartsView(viewModel: HistoryViewModel())
    }
} 
