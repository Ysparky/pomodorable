import SwiftUI

struct WeekDaySelector: View {
    @Binding var selectedDate: Date
    @Binding var isDateSelected: Bool
    let onDateSelected: (Date) -> Void
    
    @State private var weekDays: [Date] = []
    @State private var weekLabels: [String] = ["D", "L", "M", "X", "J", "V", "S"]
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
//            Text("Calendario")
//                .font(.headline)
//                .padding(.horizontal)
            
            VStack(spacing: 8) {
                // Días de la semana
                HStack(spacing: 0) {
                    ForEach(weekLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Selector de días
                HStack(spacing: 8) {
                    ForEach(weekDays, id: \.self) { date in
                        DayButton(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date)
                        )
                        .onTapGesture {
                            selectedDate = date
                            isDateSelected = true
                            onDateSelected(date)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .onAppear {
            generateWeekDays()
        }
    }
    
    private func generateWeekDays() {
        let today = Date()
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Domingo es el primer día (1)
        
        // Obtener el inicio de la semana actual
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        // Generar array con los 7 días de la semana
        weekDays = (0..<7).map { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)!
        }
    }
}

struct DayButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 40, height: 40)
            
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16))
                    .fontWeight(isSelected || isToday ? .bold : .medium)
                    .foregroundColor(textColor)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isToday {
            return Color.accentColor.opacity(0.15)
        } else {
            return Color(.tertiarySystemGroupedBackground)
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else {
            return .primary
        }
    }
}

struct WeekDaySelector_Previews: PreviewProvider {
    static var previews: some View {
        WeekDaySelector(
            selectedDate: .constant(Date()),
            isDateSelected: .constant(false),
            onDateSelected: { _ in }
        )
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
} 
