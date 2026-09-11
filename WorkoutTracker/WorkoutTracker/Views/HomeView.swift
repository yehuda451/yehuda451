import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \WorkoutSession.createdAt) private var sessions: [WorkoutSession]
    @Query(sort: \WorkoutLog.date, order: .reverse) private var logs: [WorkoutLog]

    @State private var sessionToStart: WorkoutSession?

    private var todayLog: WorkoutLog? {
        logs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var streak: Int {
        StreakCalculator.currentStreak(from: logs)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let todayLog {
                        completedTodayCard(todayLog)
                    } else {
                        quickStartSection
                    }

                    if !sessions.isEmpty {
                        recentSessionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Workout Tracker")
            .fullScreenCover(item: $sessionToStart) { session in
                ActiveWorkoutView(session: session)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text(Date.now, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Let's train")
                    .font(.largeTitle.bold())
            }
            Spacer()
            StreakBadge(streak: streak)
        }
    }

    private func completedTodayCard(_ log: WorkoutLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Workout complete for today!", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text("\(log.sessionName) · \(log.durationMinutes) min · \(log.exercisesCompleted)/\(log.totalExercises) exercises")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start today's workout")
                .font(.headline)

            if sessions.isEmpty {
                emptyStateCard
            } else {
                ForEach(sessions) { session in
                    Button {
                        sessionToStart = session
                    } label: {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No workout sessions yet")
                .font(.subheadline.bold())
            Text("Head to the Sessions tab to build your first routine.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.headline)
            WeekStrip(logs: logs)
        }
    }
}

private struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.symbolName)
                .font(.title2)
                .foregroundStyle(Color(hex: session.colorHex))
                .frame(width: 44, height: 44)
                .background(Color(hex: session.colorHex).opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name).font(.body.bold())
                Text("\(session.exercises.count) exercises · ~\(session.estimatedMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.title)
                .foregroundStyle(Color(hex: session.colorHex))
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary))
    }
}

private struct WeekStrip: View {
    let logs: [WorkoutLog]
    private let calendar = Calendar.current

    private var weekDates: [Date] {
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    var body: some View {
        HStack {
            ForEach(weekDates, id: \.self) { date in
                let didWorkout = logs.contains { calendar.isDate($0.date, inSameDayAs: date) }
                let isToday = calendar.isDateInToday(date)
                VStack(spacing: 6) {
                    Text(date, format: .dateTime.weekday(.narrow))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ZStack {
                        Circle()
                            .fill(didWorkout ? Color.accentColor : Color.clear)
                            .frame(width: 30, height: 30)
                        if isToday {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                                .frame(width: 30, height: 30)
                        }
                        if didWorkout {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.caption2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

enum StreakCalculator {
    static func currentStreak(from logs: [WorkoutLog]) -> Int {
        let calendar = Calendar.current
        let days = Set(logs.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: .now)

        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            guard days.contains(cursor) else { return 0 }
        }

        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func bestStreak(from logs: [WorkoutLog]) -> Int {
        let calendar = Calendar.current
        let days = Set(logs.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !days.isEmpty else { return 0 }

        var best = 1
        var current = 1
        for i in 1..<days.count {
            if let expected = calendar.date(byAdding: .day, value: 1, to: days[i - 1]), expected == days[i] {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
        }
        return best
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [WorkoutSession.self, WorkoutLog.self], inMemory: true)
}
