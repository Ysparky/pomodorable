import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showClearConfirmation = false
    @State private var viewMode: ViewMode = .list
    
    enum ViewMode {
        case list
        case charts
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Timeframe selector con estilo mejorado
                    Picker("Timeframe", selection: $viewModel.selectedTimeframe) {
                        ForEach(HistoryViewModel.Timeframe.allCases) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    
                    // Stats summary
                    SummaryCardView(viewModel: viewModel)
                        .id("\(viewModel.selectedTimeframe)-\(viewModel.totalSessionsForSelectedTimeframe)-\(viewModel.totalMinutesForSelectedTimeframe)")
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    
                    // Content based on selected view mode
                    if viewMode == .list {
                        // List of sessions
                        List {
                            ForEach(viewModel.sessionsByDay.keys.sorted(by: >), id: \.self) { day in
                                if let sessions = viewModel.sessionsByDay[day] {
                                    Section(header: Text(formatDateString(day))) {
                                        ForEach(sessions.sorted(by: { $0.startTime > $1.startTime })) { session in
                                            SessionRowView(session: session)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                        .refreshable {
                            viewModel.refreshHistory()
                        }
                    } else {
                        // Charts view
                        ScrollView {
                            ProductivityChartsView(viewModel: viewModel)
                                .padding(.top, 4)
                                .padding(.bottom)
                        }
                        .background(Color(.systemGroupedBackground))
                        .refreshable {
                            viewModel.refreshHistory()
                        }
                    }
                }
            }
            .navigationTitle("Historial")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // View mode selector en la barra de navegación
                        Picker("", selection: $viewMode) {
                            Image(systemName: "list.bullet").tag(ViewMode.list)
                            Image(systemName: "chart.xyaxis.line").tag(ViewMode.charts)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 100)
                        
                        // Menú de opciones
                        Menu {
                            Button(role: .destructive, action: {
                                showClearConfirmation = true
                            }) {
                                Label("Borrar todo el historial", systemImage: "trash")
                            }
                            
                            Button(action: {
                                viewModel.clearHistoryOlderThan30Days()
                            }) {
                                Label("Borrar anterior a 30 días", systemImage: "clock.arrow.circlepath")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Borrar todo el historial", isPresented: $showClearConfirmation) {
                Button("Cancelar", role: .cancel) { }
                Button("Borrar", role: .destructive) {
                    viewModel.clearAllHistory()
                }
            } message: {
                Text("Esta acción no se puede deshacer.")
            }
        }
        .onAppear {
            viewModel.refreshHistory() // Refresh when view appears
        }
    }
    
    private func formatDateString(_ dateString: String) -> String {
        // Convert "yyyy-MM-dd" to a more readable format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = dateFormatter.date(from: dateString) {
            // Today, Yesterday, or actual date
            if Calendar.current.isDateInToday(date) {
                return "Hoy"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Ayer"
            } else {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "EEEE, d MMM"
                displayFormatter.locale = Locale(identifier: "es_ES")
                return displayFormatter.string(from: date)
            }
        }
        
        return dateString
    }
}

struct SummaryCardView: View {
    @ObservedObject var viewModel: HistoryViewModel
    
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 30) {
                Spacer()
                
                StatView(
                    title: "Sesiones",
                    value: "\(viewModel.totalSessionsForSelectedTimeframe)",
                    icon: "timer",
                    color: .green
                )
                
                Divider()
                    .frame(height: 40)
                
                StatView(
                    title: "Minutos",
                    value: "\(viewModel.totalMinutesForSelectedTimeframe)",
                    icon: "clock",
                    color: .blue
                )
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Información contextual según el timeframe seleccionado
            if let mostProductiveInfo = getMostProductiveInfo() {
                HStack {
                    Image(systemName: mostProductiveInfo.icon)
                        .foregroundColor(mostProductiveInfo.color)
                        .font(.system(size: 14))
                    
                    Text(mostProductiveInfo.text)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                .padding(.bottom, 2)
            }
        }
    }
    
    // Estructura para mantener la información sobre productividad
    private struct ProductivityInfo {
        let text: String
        let icon: String
        let color: Color
    }
    
    // Devuelve la información contextual según el timeframe seleccionado
    private func getMostProductiveInfo() -> ProductivityInfo? {
        switch viewModel.selectedTimeframe {
        case .daily:
            // Para "Hoy", mostrar la hora más productiva
            if let mostProductiveTime = viewModel.mostProductiveTimeOfDay {
                return ProductivityInfo(
                    text: "Más productivo: \(translateTimeOfDay(mostProductiveTime))",
                    icon: "clock.fill", 
                    color: .yellow
                )
            }
            return nil
            
        case .weekly:
            // Para "Esta Semana", mostrar el día más productivo
            if let (dayName, count) = viewModel.getMostProductiveDayOfWeek() {
                return ProductivityInfo(
                    text: "Día más productivo: \(dayName) (\(count) sesiones)",
                    icon: "calendar",
                    color: .orange
                )
            }
            return nil
            
        case .monthly:
            // Para "Este Mes", mostrar la fecha más productiva
            if let (date, count) = viewModel.getMostProductiveDateOfMonth() {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "d MMM"
                dateFormatter.locale = Locale(identifier: "es_ES")
                let dateString = dateFormatter.string(from: date)
                
                return ProductivityInfo(
                    text: "Fecha más productiva: \(dateString) (\(count) sesiones)",
                    icon: "star.fill",
                    color: .yellow
                )
            }
            return nil
        }
    }
    
    private func translateTimeOfDay(_ timeOfDay: String) -> String {
        switch timeOfDay {
        case "Morning":
            return "Mañana"
        case "Afternoon":
            return "Tarde"
        case "Evening":
            return "Atardecer"
        case "Night":
            return "Noche"
        default:
            return timeOfDay
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct SessionRowView: View {
    let session: PomodoroSession
    
    var body: some View {
        HStack(spacing: 14) {
            // Indicador de tipo de sesión
            ZStack {
                Circle()
                    .fill(session.isCompleted ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "cup.and.saucer.fill")
                    .font(.system(size: 18))
                    .foregroundColor(session.isCompleted ? .green : .blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.isCompleted ? "Sesión Pomodoro" : "Descanso")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(session.durationString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(session.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Fecha de la sesión si es más de 1 día atrás
            if !Calendar.current.isDateInToday(session.startTime) && !Calendar.current.isDateInYesterday(session.startTime) {
                Text(formatShortDate(session.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
} 