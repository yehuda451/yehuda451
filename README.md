# Workout Tracker

A native iOS app (SwiftUI + SwiftData) for tracking your workout routine.

## Features

- **Workout sessions** — build reusable routines (e.g. "Push Day", "Leg Day") from a
  built-in exercise library covering chest, back, legs, shoulders, arms, core and
  cardio, or add your own custom exercises. Assign each session one or more days
  of the week it's meant to happen on.
- **Daily calendar** — a monthly calendar shows every day you worked out (filled,
  colored dot) and every day with a session scheduled but not yet done (dashed
  ring). Tap any day to see its details, delete a logged entry, or manually log a
  workout you did outside the app's timer.
- **iPhone Calendar sync** — optionally sync a session's scheduled days into a
  dedicated "Workout Tracker" calendar in the iOS Calendar app via EventKit, so
  your routine shows up alongside the rest of your schedule.
- **Reminders** — pick the days of the week and a time, and the app schedules local
  notifications to nudge you to work out.
- **Active workout timer** — start any session and the app walks you through each
  exercise: a countdown ring for work and rest periods, automatic set/exercise
  progression, pause/skip controls, and audio + haptic cues so you don't need to
  watch the screen — a tick for each of the final 3 seconds of work/rest, and a
  distinct chime on every transition. Cues mix with music/podcasts already
  playing and work even if the phone is muted.
- **Stats & streaks** — current streak, best streak, total workouts, total minutes,
  favorite session, and a 12-week bar chart of workout frequency.
- **Home tab** — today's plan, a week-at-a-glance strip, and a quick-start button.

## Project layout

```
WorkoutTracker/
├── WorkoutTracker.xcodeproj/       Xcode project
└── WorkoutTracker/
    ├── WorkoutTrackerApp.swift     App entry point, SwiftData container, notification setup
    ├── Models/                     Exercise, WorkoutSession, WorkoutLog, ReminderSettings
    ├── Services/                   ExerciseLibrary, NotificationManager, WorkoutTimerManager, CalendarSyncManager, WorkoutSoundManager
    ├── Views/                      All SwiftUI screens
    ├── Sounds/                     tick.wav, chime.wav — countdown/transition audio cues
    └── Assets.xcassets             App icon + accent color
```

Data model:
- `WorkoutSession` (SwiftData) — a reusable template: name, color, icon, an ordered
  list of exercises (sets/reps or sets/duration + rest), which weekdays it's
  scheduled for, and whether it syncs to the iOS Calendar.
- `WorkoutLog` (SwiftData) — one row per completed day: which session, how long,
  how many exercises. This is what powers the calendar, streaks and stats.
- `ReminderSettings` — stored in `UserDefaults`; drives scheduled local
  notifications via `UNUserNotificationCenter`.
- `CalendarSyncManager` — wraps EventKit to create/update/remove a recurring
  weekly event per session in a dedicated "Workout Tracker" calendar.

## Opening the project

1. You'll need a Mac with **Xcode 16 or later**.
2. Open `WorkoutTracker/WorkoutTracker.xcodeproj`.
3. Select your own Team under the target's **Signing & Capabilities** tab (the
   bundle identifier `com.workouttracker.app` is a placeholder — change it if
   you want to install on a real device, since bundle IDs must be unique per
   developer account).
4. Choose an iPhone simulator (or your device) and hit Run (⌘R).

The app targets **iOS 17.0+** and has no third-party dependencies — everything is
built on SwiftUI, SwiftData, and UserNotifications from the standard SDK.

## Notes

- Local notifications require the user to grant permission; the app requests this
  automatically on first launch and again if you enable reminders.
- Calendar sync requests write-only Calendar access (`NSCalendarsWriteOnlyAccessUsageDescription`)
  the first time you enable it on a session — the app can add/update/remove its
  own events but can't read your other calendar entries.
- All data is stored on-device (SwiftData); there's no backend or account system.
