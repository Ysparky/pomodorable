import SwiftUI

struct TaskScheduleSelector: View {
    @Binding var selectedDate: Date
    @Binding var isDateSelected: Bool
    var onDateSelected: (Date) -> Void

    @State private var weekDays: [Date] = []
    @State private var dayLabels: [String] = []
    private let calendar = Calendar.current

    var body: some View {
        // Simplified interface similar to the reference image
        VStack(spacing: 4) {
            // Row of day labels
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Text(dayLabels[safe: index] ?? "")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            // Row of day numbers
            HStack(spacing: 0) {
                ForEach(weekDays.indices, id: \.self) { index in
                    if index < weekDays.count {
                        let date = weekDays[index]
                        DayPill(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date)
                        )
                        .onTapGesture {
                            selectedDate = date
                            isDateSelected = true
                            onDateSelected(date)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .padding(.vertical, 8)
        .onAppear {
            generateLastSevenDays()
        }
    }

    private func generateLastSevenDays() {
        let today = Date()
        let calendar = Calendar.current

        // Generate array with past dates and the current day, keeping a total of 7 days
        var days: [Date] = []
        let daysToShow = 7
        var dayOffset = 0

        while days.count < daysToShow {
            let dayToAdd = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            // Only add if it's the current or previous day
            if calendar.compare(dayToAdd, to: today, toGranularity: .day) != .orderedDescending {
                days.insert(dayToAdd, at: 0)  // Insert at the beginning to maintain chronological order
            }
            dayOffset += 1
        }

        // Assign days in chronological order
        weekDays = days

        // Generate corresponding day labels
        dayLabels = weekDays.map { date in
            let weekday = calendar.component(.weekday, from: date)
            return formatWeekdayToShortName(weekday)
        }
    }

    private func formatWeekdayToShortName(_ weekday: Int) -> String {
        // weekday: 1 = Sunday, 2 = Monday, ... 7 = Saturday
        switch weekday {
        case 1: return "D"
        case 2: return "L"
        case 3: return "M"
        case 4: return "X"
        case 5: return "J"
        case 6: return "V"
        case 7: return "S"
        default: return ""
        }
    }
}

// Extension to safely access arrays
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct DayPill: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool

    private let calendar = Calendar.current

    var body: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.system(size: 16))
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(textColor)
            .frame(width: 32, height: 32)
            .background(backgroundColor)
            .clipShape(Circle())
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isToday {
            return Color.accentColor.opacity(0.15)
        } else {
            return Color.clear
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

struct TaskScheduleSelector_Previews: PreviewProvider {
    static var previews: some View {
        TaskScheduleSelector(
            selectedDate: .constant(Date()),
            isDateSelected: .constant(false),
            onDateSelected: { _ in }
        )
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
