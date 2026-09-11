import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \WorkoutLog.date) private var logs: [WorkoutLog]

    private var currentStreak: Int { StreakCalculator.currentStreak(from: logs) }
    private var bestStreak: Int { StreakCalculator.bestStreak(from: logs) }

    private var totalWorkouts: Int { logs.count }

    private var totalMinutes: Int { logs.reduce(0) { $0 + $1.durationMinutes } }

    private var favoriteSession: String {
        let counts = Dictionary(grouping: logs, by: \.sessionName).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? "—"
    }

    private var lastTwelveWeeks: [WeekCount] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<12).reversed().map { weeksAgo in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: today)!
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
            let count = logs.filter { $0.date >= weekStart && $0.date < weekEnd }.count
            let label = weeksAgo == 0 ? "Now" : "-\(weeksAgo)w"
            return WeekCount(label: label, count: count)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statGrid

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last 12 Weeks")
                            .font(.headline)
                        weeklyChart
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("Stats")
        }
    }

    private var statGrid: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(title: "Current Streak", value: "\(currentStreak)", icon: "flame.fill", color: .orange)
                statCard(title: "Best Streak", value: "\(bestStreak)", icon: "trophy.fill", color: .yellow)
                statCard(title: "Total Workouts", value: "\(totalWorkouts)", icon: "checkmark.seal.fill", color: .green)
                statCard(title: "Total Minutes", value: "\(totalMinutes)", icon: "clock.fill", color: .blue)
            }
            statCard(title: "Favorite Session", value: favoriteSession, icon: "star.fill", color: .purple)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary))
    }

    private var weeklyChart: some View {
        let maxCount = max(lastTwelveWeeks.map { $0.count }.max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(lastTwelveWeeks) { week in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(week.count == 0 ? 0.2 : 1))
                        .frame(height: max(4, CGFloat(week.count) / CGFloat(maxCount) * 100))
                    Text(week.label)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 130, alignment: .bottom)
    }
}

private struct WeekCount: Identifiable {
    let label: String
    let count: Int
    var id: String { label }
}

#Preview {
    StatsView()
        .modelContainer(for: [WorkoutSession.self, WorkoutLog.self], inMemory: true)
}
