import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \WorkoutLog.date) private var logs: [WorkoutLog]
    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay: Date?

    private let calendar = Calendar.current

    private var logsByDay: [Date: WorkoutLog] {
        Dictionary(uniqueKeysWithValues: logs.map { (calendar.startOfDay(for: $0.date), $0) })
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }
        let leadingBlanks = firstWeekday - 1
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        var day = monthInterval.start
        while day < monthInterval.end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                monthHeader

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(Weekday.allCases) { day in
                        Text(day.shortLabel.prefix(1))
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(date)
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal)

                if !logs.isEmpty {
                    legend
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Calendar")
            .sheet(item: Binding(
                get: { selectedDay.map { IdentifiableDate(date: $0) } },
                set: { selectedDay = $0?.date }
            )) { wrapped in
                DayDetailView(date: wrapped.date, log: logsByDay[calendar.startOfDay(for: wrapped.date)])
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal)
    }

    private func dayCell(_ date: Date) -> some View {
        let log = logsByDay[calendar.startOfDay(for: date)]
        let isToday = calendar.isDateInToday(date)

        return Button {
            selectedDay = date
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.footnote.bold())
                    .foregroundStyle(log != nil ? .white : .primary)
                if let log {
                    Image(systemName: log.symbolName)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                Circle()
                    .fill(log != nil ? Color(hex: log!.colorHex) : Color.clear)
                    .padding(2)
            )
            .overlay(
                Circle().strokeBorder(isToday ? Color.accentColor : .clear, lineWidth: 1.5).padding(2)
            )
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                Text("Completed").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func shiftMonth(_ value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

#Preview {
    CalendarView()
        .modelContainer(for: [WorkoutSession.self, WorkoutLog.self], inMemory: true)
}
