import Foundation
import EventKit

/// Syncs scheduled workout sessions into a dedicated calendar in the
/// user's iPhone Calendar app as recurring weekly events.
final class CalendarSyncManager {
    static let shared = CalendarSyncManager()
    private let store = EKEventStore()
    private let calendarTitle = "Workout Tracker"

    private init() {}

    func requestAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        store.requestWriteOnlyAccessToEvents { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Creates/updates a recurring event covering every scheduled day for
    /// this session, or removes it if the session no longer syncs.
    func sync(session: WorkoutSession, hour: Int, minute: Int) {
        removeEvent(for: session)

        guard session.syncsToCalendar, !session.scheduledDays.isEmpty,
              let calendar = workoutCalendar() else { return }

        let event = EKEvent(eventStore: store)
        event.title = "🏋️ \(session.name)"
        event.notes = "Workout Tracker session · \(session.exercises.count) exercises"
        event.calendar = calendar

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = hour
        comps.minute = minute
        let startDate = Calendar.current.date(from: comps) ?? .now
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(TimeInterval(session.estimatedMinutes * 60))

        let days = session.scheduledDays.map { EKRecurrenceDayOfWeek(EKWeekday(rawValue: $0.rawValue) ?? .monday) }
        event.recurrenceRules = [
            EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, daysOfTheWeek: days, daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)
        ]

        do {
            try store.save(event, span: .futureEvents)
            session.calendarEventIdentifier = event.eventIdentifier
        } catch {
            session.calendarEventIdentifier = nil
        }
    }

    func removeEvent(for session: WorkoutSession) {
        guard let identifier = session.calendarEventIdentifier,
              let event = store.event(withIdentifier: identifier) else { return }
        try? store.remove(event, span: .futureEvents)
        session.calendarEventIdentifier = nil
    }

    private func workoutCalendar() -> EKCalendar? {
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            return existing
        }
        guard let source = store.defaultCalendarForNewEvents?.source ?? store.sources.first(where: { $0.sourceType == .local }) else {
            return nil
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarTitle
        calendar.source = source
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            return nil
        }
    }
}
