# FileVault

A native iOS download manager and file browser (SwiftUI), in the spirit of
**Documents by Readdle** and **Total Files**: fetch files from a direct link or
a built-in browser, then organize, preview, compress and share them without
leaving the app.

## Features

- **Download manager** — paste a link (or use the built-in browser) and
  FileVault fetches it over a background `URLSession`, so downloads keep
  going while the app is suspended or you switch tabs. Each item shows live
  progress, and can be paused, resumed, retried, or cancelled.
- **Built-in browser** — a lightweight `WKWebView`-based browser with an
  address bar, back/forward/reload, and a download button. It automatically
  hands off any link it can't render inline (a `.zip`, `.dmg`, `.apk`, …) to
  the download manager instead of failing to load it — the same trick
  Documents' browser uses, since Safari won't let a tap "download" an
  arbitrary file.
- **File browser** — navigate the app's on-device storage as folders, in a
  list or grid layout, sorted by name/date/size, with search. Multi-select
  supports batch move, compress, share, and delete.
- **File operations** — create folders, rename, duplicate, move, delete,
  import from the Files app (`.fileImporter`), and share via the system share
  sheet (AirDrop, Mail, other apps, …).
- **Preview** — tap any file to preview it in place via QuickLook (images,
  PDFs, video, text, and anything else QuickLook natively supports).
- **Zip / unzip** — compress one or more files/folders into a `.zip`, or
  extract an existing archive into a new folder, no third-party dependencies.
- **Files app integration** — FileVault's storage is exposed under
  **On My iPhone → FileVault**, so anything it downloads or organizes is
  immediately visible to every other Files-app-aware app.

## Project layout

```
FileVault/
├── FileVault.xcodeproj/        Xcode project
└── FileVault/
    ├── FileVaultApp.swift      App entry point + AppDelegate for background URLSession events
    ├── Info.plist              ATS exception for the browser, Files-app exposure, doc types
    ├── Models/                 DownloadItem, FileNode, SortOption
    ├── Services/
    │   ├── DownloadEngine.swift    Background URLSession download manager (pause/resume/retry)
    │   ├── DownloadStore.swift     Persists the download queue as JSON
    │   ├── FileSystemService.swift Directory listing + create/rename/move/copy/delete
    │   └── ZipService.swift        Zip (NSFileCoordinator) / unzip (hand-rolled ZIP reader)
    ├── Views/                  All SwiftUI screens (Downloads, Files, Browser, Settings)
    └── Assets.xcassets         App icon + accent color
```

Data flow:
- `DownloadEngine` is a singleton `ObservableObject` wrapping a background
  `URLSession`. It's the only thing that talks to `URLSessionDownloadTask`;
  everything else (the Downloads tab, the browser's download button) just
  calls `DownloadEngine.shared.startDownload(from:suggestedName:)`.
- Finished downloads land in `Documents/Downloads/`; the file browser's root
  is `Documents/`, so they show up there (and in the Files app) immediately.
  Bookkeeping (the JSON queue) lives in Application Support, out of view.
- `FileSystemService` is a stateless set of helpers around `FileManager` —
  no view owns file state beyond its own directory listing, so the browser
  is just `FileBrowserView(directory:)` recursing into itself for subfolders.

## Opening the project

1. You'll need a Mac with **Xcode 16 or later**.
2. Open `FileVault/FileVault.xcodeproj`.
3. Select your own Team under the target's **Signing & Capabilities** tab
   (the bundle identifier `com.filevault.app` is a placeholder — change it if
   you want to install on a real device, since bundle IDs must be unique per
   developer account).
4. Choose an iPhone simulator (or your device) and hit Run (⌘R).

The app targets **iOS 17.0+** and has no third-party dependencies — everything
is built on SwiftUI, Foundation, WebKit, QuickLook, and the `Compression`
framework from the standard SDK.

## Notes

- **App Transport Security** is relaxed (`NSAllowsArbitraryLoads`) so the
  built-in browser can reach plain `http://` sites and arbitrary download
  hosts, the same way Safari can — that's the whole point of the browser tab.
- **Zip/unzip limitations**: extraction supports the common "stored" and
  "deflated" entry types (what `zip`, Finder, and Windows all produce) but not
  encrypted archives or Zip64 (>4GB archives or >65,535 entries) — edge cases
  that don't come up with phone-sized downloads.
- Background downloads rely on `URLSessionConfiguration.background(...)` and
  `handleEventsForBackgroundURLSession` — the transfer itself is driven by
  the OS, not the app process, so it continues even if FileVault is
  suspended or the phone reboots the app.
- All data is stored on-device; there's no backend or account system.
