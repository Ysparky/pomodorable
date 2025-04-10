import SwiftUI

struct CalendarView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var selectedMonth = Date()

    private let calendar = Calendar.current
    private let daysOfWeek = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month selector
                HStack {
                    Button(action: {
                        selectedMonth =
                            calendar.date(byAdding: .month, value: -1, to: selectedMonth)
                            ?? selectedMonth
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.accentColor)
                    }

                    Spacer()

                    Text(monthYearString(from: selectedMonth))
                        .font(.headline)

                    Spacer()

                    Button(action: {
                        selectedMonth =
                            calendar.date(byAdding: .month, value: 1, to: selectedMonth)
                            ?? selectedMonth
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.accentColor)
                    }
                }
                .padding()

                // Day headers
                HStack(spacing: 0) {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 8)

                // Day grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(daysInMonth(), id: \.id) { dayItem in
                        if let date = dayItem.date {
                            DayCell(
                                date: date,
                                selectedDate: $selectedDate,
                                isToday: calendar.isDateInToday(date),
                                hasSessions: viewModel.datesWithSessions.contains(where: {
                                    calendar.isDate($0, inSameDayAs: date)
                                }),
                                isFutureDate: calendar.compare(
                                    date, to: Date(), toGranularity: .day) == .orderedDescending
                            )
                            .onTapGesture {
                                // Solo permitir seleccionar fechas pasadas o el día actual
                                if calendar.compare(date, to: Date(), toGranularity: .day)
                                    != .orderedDescending
                                {
                                    selectedDate = date
                                    viewModel.selectSpecificDate(date)
                                    dismiss()
                                }
                            }
                        } else {
                            // Empty cell for days outside current month
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(height: 40)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                    // Eliminamos la sección de atajos y simplemente agregamos un padding inferior
                    .padding(.bottom, 16)
            }
            .navigationTitle("Seleccionar fecha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hoy") {
                        selectedDate = Date()
                        selectedMonth = Date()
                        viewModel.selectSpecificDate(Date())
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Cargar las fechas con sesiones
            viewModel.loadDatesWithSessions()
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date).capitalized
    }

    // Estructura para representar un día del calendario con ID único
    struct DayItem: Identifiable {
        var id: Int
        var date: Date?
    }

    private func daysInMonth() -> [DayItem] {
        // Get start of the month
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)
        guard let startOfMonth = calendar.date(from: components),
            let range = calendar.range(of: .day, in: .month, for: startOfMonth)
        else {
            return []
        }

        // Determine weekday of first day (1 = Sunday, 2 = Monday, etc.)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)

        // In Spain/ES locale, Monday is the first day (index 0), Sunday is the last (index 6)
        // Convert from calendar weekday (1 = Sunday) to our array index (0 = Monday)
        let esWeekdayOffset = (firstWeekday + 5) % 7

        // Generate array of dates with unique IDs
        var days: [DayItem] = []

        // Pad beginning with nil values (empty cells)
        for i in 0..<esWeekdayOffset {
            days.append(DayItem(id: -i - 1, date: nil))  // Negative IDs for padding at beginning
        }

        // Add days of the month with positive IDs
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else {
                continue
            }
            days.append(DayItem(id: day, date: date))
        }

        // Pad end with nil values (empty cells)
        let remainingDays = 42 - days.count  // 6 rows of 7 days
        for i in 0..<remainingDays {
            days.append(DayItem(id: 1000 + i, date: nil))  // IDs starting at 1000 for padding at end
        }

        return days
    }
}

struct DayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let isToday: Bool
    let hasSessions: Bool
    let isFutureDate: Bool

    private let calendar = Calendar.current

    var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(height: 40)

            VStack(spacing: 0) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline)
                    .fontWeight(isSelected || isToday ? .bold : .regular)
                    .foregroundColor(textColor)

                if hasSessions && !isFutureDate {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                        .padding(.top, 2)
                } else {
                    Spacer()
                        .frame(height: 7)
                }
            }
        }
        .frame(height: 40)
        .opacity(isFutureDate ? 0.4 : 1.0)
    }

    private var backgroundColor: Color {
        if isSelected && !isFutureDate {
            return Color.accentColor
        } else if isToday {
            return Color.accentColor.opacity(0.2)
        } else {
            return Color.clear
        }
    }

    private var textColor: Color {
        if isSelected && !isFutureDate {
            return .white
        } else if isFutureDate {
            return .gray
        } else {
            return .primary
        }
    }
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(viewModel: HistoryViewModel())
    }
}
