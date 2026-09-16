# iOS Apps

A collection of native iOS apps (SwiftUI), each self-contained in its own
directory with its own Xcode project and CI workflow that builds an unsigned
`.ipa` on push.

## [FileVault](FileVault/) — download manager & file browser

Fetch files from a direct link or the built-in browser, then organize,
preview, zip/unzip, and share them — in the spirit of Documents by Readdle
or Total Files. See [FileVault/README.md](FileVault/README.md).

## [WorkoutTracker](WorkoutTracker/) — workout routine tracker

Build reusable workout routines, track them on a calendar, sync to the iOS
Calendar app, get reminders, and run an active session with a countdown
timer and audio cues. See [WorkoutTracker/README.md](WorkoutTracker/README.md).

## Opening a project

Each app is independent — open its own `.xcodeproj` in Xcode (16+) rather
than anything at the repo root. See the per-app README for setup details,
minimum iOS version, and any placeholders (like the bundle identifier) you
should change before installing on a real device.
