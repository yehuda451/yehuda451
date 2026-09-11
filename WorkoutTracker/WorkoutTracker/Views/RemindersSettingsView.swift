import SwiftUI

struct RemindersSettingsView: View {
    @State private var settings = ReminderSettings.load()

    var body: some View {
        Form {
            Section {
                Toggle("Workout Reminders", isOn: $settings.isEnabled)
            } footer: {
                Text("You'll get a notification on the days and time you choose below.")
            }

            if settings.isEnabled {
                Section("Days") {
                    HStack {
                        ForEach(Weekday.allCases) { day in
                            dayToggle(day)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Time") {
                    DatePicker("Reminder Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                }

                Section("Message") {
                    TextField("Reminder message", text: $settings.message)
                }
            }
        }
        .navigationTitle("Reminders")
        .onChange(of: settings.isEnabled) { requestPermissionIfNeeded() }
        .onDisappear { persist() }
    }

    private func dayToggle(_ day: Weekday) -> some View {
        let isOn = settings.days.contains(day)
        return Button {
            if isOn {
                settings.days.remove(day)
            } else {
                settings.days.insert(day)
            }
        } label: {
            Text(day.shortLabel.prefix(1))
                .font(.caption.bold())
                .frame(width: 32, height: 32)
                .background(isOn ? Color.accentColor : Color.clear, in: Circle())
                .foregroundStyle(isOn ? .white : .primary)
                .overlay(Circle().strokeBorder(.quaternary))
        }
        .buttonStyle(.plain)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = settings.hour
                components.minute = settings.minute
                return Calendar.current.date(from: components) ?? .now
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.hour = components.hour ?? 18
                settings.minute = components.minute ?? 0
            }
        )
    }

    private func requestPermissionIfNeeded() {
        guard settings.isEnabled else { return }
        NotificationManager.shared.requestAuthorizationIfNeeded { _ in }
    }

    private func persist() {
        settings.save()
        NotificationManager.shared.reschedule(with: settings)
    }
}

#Preview {
    NavigationStack { RemindersSettingsView() }
}
