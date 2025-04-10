import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showClearConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Timeframe selector
                Picker("Timeframe", selection: $viewModel.selectedTimeframe) {
                    ForEach(HistoryViewModel.Timeframe.allCases) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Stats summary card
                SummaryCardView(viewModel: viewModel)
                
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
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: {
                            showClearConfirmation = true
                        }) {
                            Label("Clear All History", systemImage: "trash")
                        }
                        
                        Button(action: {
                            viewModel.clearHistoryOlderThan30Days()
                        }) {
                            Label("Clear Older Than 30 Days", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Clear All History", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    viewModel.clearAllHistory()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func formatDateString(_ dateString: String) -> String {
        // Convert "yyyy-MM-dd" to a more readable format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = dateFormatter.date(from: dateString) {
            // Today, Yesterday, or actual date
            if Calendar.current.isDateInToday(date) {
                return "Today"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "EEEE, MMM d"
                return displayFormatter.string(from: date)
            }
        }
        
        return dateString
    }
}

struct SummaryCardView: View {
    let viewModel: HistoryViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatView(
                    title: "Sessions",
                    value: "\(viewModel.totalSessionsForSelectedTimeframe)",
                    icon: "timer"
                )
                
                Divider()
                    .frame(height: 40)
                
                StatView(
                    title: "Minutes",
                    value: "\(viewModel.totalMinutesForSelectedTimeframe)",
                    icon: "clock"
                )
            }
            
            if let mostProductiveTime = viewModel.mostProductiveTimeOfDay {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    
                    Text("Most productive: \(mostProductiveTime)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

struct StatView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
    }
}

struct SessionRowView: View {
    let session: PomodoroSession
    
    var body: some View {
        HStack {
            Circle()
                .fill(session.isCompleted ? Color.green : Color.blue)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading) {
                Text(session.isCompleted ? "Focus Session" : "Break")
                    .font(.headline)
                
                Text("\(session.durationString) • \(formatTime(session.startTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: session.isCompleted ? "checkmark.circle" : "cup.and.saucer")
                .foregroundColor(session.isCompleted ? .green : .blue)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
} 