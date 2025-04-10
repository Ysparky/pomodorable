import SwiftUI
import Charts

struct ProductivityChartsView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var selectedChartType: ChartType = .daily
    
    enum ChartType: String, CaseIterable, Identifiable {
        case daily = "Por Día"
        case hourly = "Por Hora"
        case trend = "Tendencia"
        case weekly = "Semanal"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Chart type selector
            Picker("Tipo de Gráfico", selection: $selectedChartType) {
                ForEach(ChartType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Chart display
            switch selectedChartType {
            case .daily:
                DailySessionsChart(sessions: viewModel.sessionsForSelectedTimeframe)
            case .hourly:
                HourlyDistributionChart(sessions: viewModel.sessionsForSelectedTimeframe)
            case .trend:
                ProductivityTrendChart(sessions: viewModel.sessionsForSelectedTimeframe)
            case .weekly:
                WeekdayProductivityChart(viewModel: viewModel)
            }
        }
    }
}

// Gráfico de barras que muestra sesiones por día
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
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Sesiones Completadas por Día")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart(sessionsPerDay) { dayData in
                    BarMark(
                        x: .value("Día", dayData.day),
                        y: .value("Sesiones", dayData.completedSessions)
                    )
                    .foregroundStyle(Color.green.gradient)
                }
                .frame(height: 220)
                .padding()
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            } else {
                // Fallback para iOS 15 o anterior
                Text("Gráficos disponibles en iOS 16 o superior")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

// Gráfico circular que muestra distribución de sesiones por hora del día
struct HourlyDistributionChart: View {
    let sessions: [PomodoroSession]
    
    var sessionsByTimeOfDay: [TimeOfDayData] {
        let completedSessions = sessions.filter { $0.isCompleted }
        let groupedByTime = Dictionary(grouping: completedSessions) { $0.timeOfDayString }
        
        let result = [
            TimeOfDayData(timeOfDay: "Morning", label: "Mañana", count: groupedByTime["Morning"]?.count ?? 0),
            TimeOfDayData(timeOfDay: "Afternoon", label: "Tarde", count: groupedByTime["Afternoon"]?.count ?? 0),
            TimeOfDayData(timeOfDay: "Evening", label: "Atardecer", count: groupedByTime["Evening"]?.count ?? 0),
            TimeOfDayData(timeOfDay: "Night", label: "Noche", count: groupedByTime["Night"]?.count ?? 0)
        ]
        
        return result.filter { $0.count > 0 }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Distribución por Hora del Día")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart(sessionsByTimeOfDay) { timeData in
                    SectorMark(
                        angle: .value("Sesiones", timeData.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("Hora", timeData.label))
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
                .padding()
            } else {
                // Fallback para iOS 15 o anterior
                Text("Gráficos disponibles en iOS 16 o superior")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

// Gráfico de líneas que muestra tendencia de productividad
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
        VStack(alignment: .leading) {
            Text("Tendencia de Productividad")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart(productivityTrend) { dataPoint in
                    LineMark(
                        x: .value("Día", dataPoint.day),
                        y: .value("Minutos", dataPoint.totalMinutes)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Día", dataPoint.day),
                        y: .value("Minutos", dataPoint.totalMinutes)
                    )
                    .foregroundStyle(Color.blue)
                }
                .frame(height: 220)
                .padding()
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            } else {
                // Fallback para iOS 15 o anterior
                Text("Gráficos disponibles en iOS 16 o superior")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

// Gráfico que muestra la productividad por día de la semana
struct WeekdayProductivityChart: View {
    @ObservedObject var viewModel: HistoryViewModel
    
    var weekdayData: [WeekdayProductivityData] {
        // Obtener los datos de productividad por día de la semana
        let productivityData = viewModel.productivityByDayOfWeek
        
        // Orden de días de la semana (lunes a domingo)
        let weekdayOrder = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
        
        // Convertir a arreglo para el gráfico
        return weekdayOrder.map { day in
            let data = productivityData[day]!
            return WeekdayProductivityData(
                day: day,
                sessions: data.sessions,
                minutes: data.minutes
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Productividad por Día de la Semana")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(weekdayData) { item in
                        BarMark(
                            x: .value("Día", item.day),
                            y: .value("Sesiones", item.sessions)
                        )
                        .foregroundStyle(Color.green.gradient)
                    }
                    
                    ForEach(weekdayData) { item in
                        LineMark(
                            x: .value("Día", item.day),
                            y: .value("Minutos", item.minutes)
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
                .padding()
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartForegroundStyleScale([
                    "Sesiones": Color.green,
                    "Minutos": Color.blue
                ])
                .chartLegend(position: .bottom, alignment: .center)
            } else {
                // Fallback para iOS 15 o anterior
                Text("Gráficos disponibles en iOS 16 o superior")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Análisis:")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text(getMostProductiveDay())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
    
    private func getMostProductiveDay() -> String {
        let data = weekdayData
        
        if let mostSessions = data.max(by: { $0.sessions < $1.sessions }) {
            return "Tu día más productivo en sesiones es \(translateDayName(mostSessions.day)) con \(mostSessions.sessions) sesiones completadas."
        } else {
            return "Aún no hay suficientes datos para determinar tu día más productivo."
        }
    }
    
    private func translateDayName(_ shortName: String) -> String {
        switch shortName {
        case "Lun": return "Lunes"
        case "Mar": return "Martes"
        case "Mié": return "Miércoles"
        case "Jue": return "Jueves"
        case "Vie": return "Viernes"
        case "Sáb": return "Sábado"
        case "Dom": return "Domingo"
        default: return shortName
        }
    }
}

// Modelos de datos para los gráficos
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