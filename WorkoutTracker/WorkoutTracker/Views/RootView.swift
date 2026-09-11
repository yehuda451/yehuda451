import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            SessionListView()
                .tabItem { Label("Sessions", systemImage: "list.bullet.rectangle") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [WorkoutSession.self, WorkoutLog.self], inMemory: true)
}
