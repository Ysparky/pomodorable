import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showClearConfirmation = false
    @State private var viewMode: ViewMode = .list
    @State private var showCalendar = false
    
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
                    // Título y fecha en lugar del botón de calendario
                    HStack {
                        Text(viewModel.dateTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            showCalendar = true
                        }) {
                            HStack(spacing: 4) {
                                Text("Calendario")
                                    .font(.subheadline)
                                
                                Image(systemName: "calendar")
                                    .font(.footnote)
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // TaskScheduleSelector en lugar del Picker de timeframe
                    TaskScheduleSelector(
                        selectedDate: Binding(
                            get: { self.viewModel.selectedDate },
                            set: { 
                                self.viewModel.selectedDate = $0
                                self.viewModel.isCustomDateSelected = true
                                self.viewModel.selectSpecificDate($0)
                            }
                        ),
                        isDateSelected: Binding(
                            get: { self.viewModel.isCustomDateSelected },
                            set: { self.viewModel.isCustomDateSelected = $0 }
                        ),
                        onDateSelected: { date in
                            self.viewModel.selectSpecificDate(date)
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 0)
                    
                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    
                    // Stats summary
                    SummaryCardView(viewModel: viewModel)
                        .id("\(viewModel.selectedDate)-\(viewModel.totalSessionsForSelectedTimeframe)-\(viewModel.totalMinutesForSelectedTimeframe)")
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    
                    // Content based on selected view mode
                    if viewMode == .list {
                        // List of sessions
                        if viewModel.sessionsForSelectedDay.isEmpty {
                            // Vista para cuando no hay sesiones
                            VStack(spacing: 16) {
                                Spacer()
                                
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                Text("No hay sesiones para este día")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    viewModel.resetToCurrentDay()
                                }) {
                                    Label("Ver hoy", systemImage: "calendar.day.timeline.leading")
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.bordered)
                                
                                Spacer()
                            }
                            .padding()
                        } else {
                            // Lista de sesiones para el día seleccionado
                            List {
                                Section {
                                    ForEach(viewModel.sessionsForSelectedDay.sorted(by: { $0.startTime > $1.startTime })) { session in
                                        SessionRowView(session: session)
                                    }
                                } header: {
                                    Text(viewModel.dateTitle)
                                }
                            }
                            .listStyle(InsetGroupedListStyle())
                            .refreshable {
                                viewModel.refreshHistory()
                            }
                        }
                    } else {
                        // Charts view
                        if viewModel.sessionsForSelectedDay.isEmpty {
                            // Vista para cuando no hay sesiones (misma que en modo lista)
                            VStack(spacing: 16) {
                                Spacer()
                                
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                Text("No hay sesiones para este día")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    viewModel.resetToCurrentDay()
                                }) {
                                    Label("Ver hoy", systemImage: "calendar.day.timeline.leading")
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.bordered)
                                
                                Spacer()
                            }
                            .padding()
                        } else {
                            // Gráficos con estilo de lista
                            ScrollView {
                                ProductivityChartsView(viewModel: viewModel)
                                    .padding(.horizontal, 0)
                                    .padding(.top, 8)
                            }
                            .background(Color(.systemGroupedBackground))
                            .listStyle(InsetGroupedListStyle())
                            .refreshable {
                                viewModel.refreshHistory()
                            }
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
                            Button(action: {
                                viewModel.resetToCurrentDay()
                            }) {
                                Label("Ver hoy", systemImage: "calendar.day.timeline.leading")
                            }
                            
                            Button(action: {
                                showCalendar = true
                            }) {
                                Label("Seleccionar fecha", systemImage: "calendar")
                            }
                            
                            Divider()
                            
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
            .sheet(isPresented: $showCalendar) {
                CalendarView(viewModel: viewModel)
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
            
            // Post notification that history tab was selected
            NotificationCenter.default.post(name: .historyTabSelected, object: nil)
        }
    }
    
    private func formatDateString(_ dateString: String, for timeframe: HistoryViewModel.Timeframe) -> String {
        // Convert "yyyy-MM-dd" to a more readable format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = dateFormatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "es_ES")
        
        // Si hay una fecha específica seleccionada, ajustar el formato
        if viewModel.isCustomDateSelected {
            let calendar = Calendar.current
            if calendar.isDate(date, inSameDayAs: viewModel.selectedDate) {
                // Si es la fecha específica seleccionada
                if calendar.isDateInToday(date) {
                    return "Hoy"
                } else if calendar.isDateInYesterday(date) {
                    return "Ayer"
                } else {
                    displayFormatter.dateFormat = "EEEE, d MMMM"
                    return displayFormatter.string(from: date).capitalized
                }
            } else {
                // Otras fechas en el periodo seleccionado
                displayFormatter.dateFormat = "EEEE, d MMMM"
                return displayFormatter.string(from: date).capitalized
            }
        }
        
        // Si no hay una fecha específica, usar el comportamiento normal por timeframe
        switch timeframe {
        case .daily:
            // Para el timeframe diario: Hoy, Ayer o fecha
            if Calendar.current.isDateInToday(date) {
                return "Hoy"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Ayer"
            } else {
                displayFormatter.dateFormat = "EEEE, d MMM"
                return displayFormatter.string(from: date)
            }
            
        case .weekly:
            // Para el timeframe semanal: Nombre del día o "Hoy"/"Ayer"
            if Calendar.current.isDateInToday(date) {
                return "Hoy"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Ayer"
            } else {
                displayFormatter.dateFormat = "EEEE"
                let dayName = displayFormatter.string(from: date).capitalized
                
                // Para días de esta semana, mostrar solo el nombre del día
                let today = Date()
                if let startOfWeek = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
                   date >= startOfWeek && date <= today {
                    return dayName
                } else {
                    // Para días fuera de esta semana, mostrar el nombre del día y la fecha
                    displayFormatter.dateFormat = "d MMM"
                    return "\(dayName), \(displayFormatter.string(from: date))"
                }
            }
            
        case .monthly:
            // Para timeframe mensual: Día del mes (1 Enero, etc.)
            let day = Calendar.current.component(.day, from: date)
            
            if Calendar.current.isDateInToday(date) {
                return "Hoy (\(day))"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Ayer (\(day))"
            } else {
                displayFormatter.dateFormat = "d MMMM"
                return displayFormatter.string(from: date)
            }
        }
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
                    value: "\(viewModel.totalSessionsForSelectedDay)",
                    icon: "timer",
                    color: .green
                )
                
                Divider()
                    .frame(height: 40)
                
                StatView(
                    title: "Minutos",
                    value: "\(viewModel.totalMinutesForSelectedDay)",
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
            
            // Información contextual para el día seleccionado
            if let productiveTime = viewModel.mostProductiveTimeOfSelectedDay {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))
                    
                    Text("Hora más productiva: \(translateTimeOfDay(productiveTime))")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                .padding(.bottom, 2)
            } else if viewModel.totalSessionsForSelectedDay == 0 {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    Text("No hay sesiones completadas en este día")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                .padding(.bottom, 2)
            }
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