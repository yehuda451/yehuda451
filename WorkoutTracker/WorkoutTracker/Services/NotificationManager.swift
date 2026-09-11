import Foundation
import UserNotifications

/// Schedules and manages local notification reminders to work out.
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let identifierPrefix = "workout-reminder-"

    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion?(granted)
                }
            case .authorized, .provisional, .ephemeral:
                completion?(true)
            default:
                completion?(false)
            }
        }
    }

    /// Cancels any existing reminders and, if enabled, schedules a repeating
    /// weekly notification for each selected day/time.
    func reschedule(with settings: ReminderSettings) {
        let center = UNUserNotificationCenter.current()
        cancelAll()

        guard settings.isEnabled, !settings.days.isEmpty else { return }

        for day in settings.days {
            var dateComponents = DateComponents()
            dateComponents.weekday = day.rawValue
            dateComponents.hour = settings.hour
            dateComponents.minute = settings.minute

            let content = UNMutableNotificationContent()
            content.title = "Workout Reminder"
            content.body = settings.message
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: identifierPrefix + "\(day.rawValue)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    func cancelAll() {
        let center = UNUserNotificationCenter.current()
        let identifiers = Weekday.allCases.map { identifierPrefix + "\($0.rawValue)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
