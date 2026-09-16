import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            FileBrowserView(directory: FileSystemService.documentsDirectory, title: "Files")
                .tabItem { Label("Files", systemImage: "folder.fill") }

            DownloadsView()
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle.fill") }

            BrowserView()
                .tabItem { Label("Browser", systemImage: "safari.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    RootView()
}
