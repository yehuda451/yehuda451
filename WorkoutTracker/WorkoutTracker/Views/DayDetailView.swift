import SwiftUI
import SwiftData

struct DayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let log: WorkoutLog?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(date, style: .date)
                    .font(.title2.bold())

                if let log {
                    VStack(spacing: 12) {
                        Image(systemName: log.symbolName)
                            .font(.system(size: 40))
                            .foregroundStyle(Color(hex: log.colorHex))
                        Text(log.sessionName)
                            .font(.title3.bold())
                        Text("\(log.durationMinutes) min · \(log.exercisesCompleted)/\(log.totalExercises) exercises")
                            .foregroundStyle(.secondary)

                        Button(role: .destructive) {
                            modelContext.delete(log)
                            dismiss()
                        } label: {
                            Label("Remove Entry", systemImage: "trash")
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                } else {
                    ContentUnavailableView(
                        "Rest Day",
                        systemImage: "moon.zzz.fill",
                        description: Text("No workout was logged on this day.")
                    )
                }

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DayDetailView(date: .now, log: nil)
}
