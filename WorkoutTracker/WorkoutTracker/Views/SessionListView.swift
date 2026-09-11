import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.createdAt) private var sessions: [WorkoutSession]

    @State private var isPresentingEditor = false
    @State private var editingSession: WorkoutSession?
    @State private var sessionToStart: WorkoutSession?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Create a workout session, like \"Push Day\" or \"Leg Day\", and fill it with exercises.")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            Button {
                                sessionToStart = session
                            } label: {
                                sessionRow(session)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(session)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingSession = session
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                SessionEditorView(session: nil)
            }
            .sheet(item: $editingSession) { session in
                SessionEditorView(session: session)
            }
            .fullScreenCover(item: $sessionToStart) { session in
                ActiveWorkoutView(session: session)
            }
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        HStack(spacing: 14) {
            Image(systemName: session.symbolName)
                .font(.title2)
                .foregroundStyle(Color(hex: session.colorHex))
                .frame(width: 40, height: 40)
                .background(Color(hex: session.colorHex).opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name).font(.body.bold())
                Text("\(session.exercises.count) exercises · ~\(session.estimatedMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "play.fill")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SessionListView()
        .modelContainer(for: [WorkoutSession.self, WorkoutLog.self], inMemory: true)
}
