# Workout Tracker

A native iOS app (SwiftUI + SwiftData) for tracking your workout routine.

## Features

- **Workout sessions** — build reusable routines (e.g. "Push Day", "Leg Day") from a
  built-in exercise library covering chest, back, legs, shoulders, arms, core and
  cardio, or add your own custom exercises.
- **Daily calendar** — a monthly calendar shows every day you worked out, with an
  icon/color for which session you did that day. Tap a day to see (or delete) its
  details.
- **Reminders** — pick the days of the week and a time, and the app schedules local
  notifications to nudge you to work out.
- **Active workout timer** — start any session and the app walks you through each
  exercise: a countdown ring for work and rest periods, automatic set/exercise
  progression, haptic + sound cues on every transition, pause/skip controls.
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
    ├── Services/                   ExerciseLibrary, NotificationManager, WorkoutTimerManager
    ├── Views/                      All SwiftUI screens
    └── Assets.xcassets             App icon slot + accent color
```

Data model:
- `WorkoutSession` (SwiftData) — a reusable template: name, color, icon, and an
  ordered list of exercises (sets/reps or sets/duration + rest).
- `WorkoutLog` (SwiftData) — one row per completed day: which session, how long,
  how many exercises. This is what powers the calendar, streaks and stats.
- `ReminderSettings` — stored in `UserDefaults`; drives scheduled local
  notifications via `UNUserNotificationCenter`.

## Opening the project

1. You'll need a Mac with **Xcode 16 or later**.
2. Open `WorkoutTracker/WorkoutTracker.xcodeproj`.
3. Select your own Team under the target's **Signing & Capabilities** tab (the
   bundle identifier `com.workouttracker.app` is a placeholder — change it if you
   want to install on a real device, since bundle IDs must be unique per developer
   account).
4. Choose an iPhone simulator (or your device) and hit Run (⌘R).

The app targets **iOS 17.0+** and has no third-party dependencies — everything is
built on SwiftUI, SwiftData, and UserNotifications from the standard SDK.

## Notes

- Local notifications require the user to grant permission; the app requests this
  automatically on first launch and again if you enable reminders.
- All data is stored on-device (SwiftData); there's no backend or account system.
- The AppIcon slot is empty — drop your own 1024×1024 icon into
  `Assets.xcassets/AppIcon.appiconset` before shipping.
