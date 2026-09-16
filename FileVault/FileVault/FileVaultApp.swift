import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Stashed by iOS when it relaunches the app in the background to deliver
    /// events (progress/completion) for a background `URLSession`. Must be called
    /// once `DownloadEngine` has finished processing those events, or the system
    /// won't re-suspend the app promptly.
    static var backgroundCompletionHandler: (() -> Void)?

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        AppDelegate.backgroundCompletionHandler = completionHandler
    }
}

@main
struct FileVaultApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Touch the shared engine on launch so it reattaches to any background
        // downloads that kept running while the app wasn't in memory.
        _ = DownloadEngine.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
