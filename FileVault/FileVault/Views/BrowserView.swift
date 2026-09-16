import SwiftUI
import WebKit

/// A minimal in-app web browser, the way Documents/Total Files use one: Safari
/// won't let a normal tap download an arbitrary file, but a `WKWebView` we control
/// can notice when a navigation isn't renderable (a .zip, .dmg, .apk, ...) and hand
/// it to `DownloadEngine` instead of failing to load it.
struct BrowserView: View {
    @State private var urlString = "https://www.apple.com"
    @State private var currentURL: URL? = URL(string: "https://www.apple.com")
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var pageTitle = ""

    @State private var navigationAction: WebViewNavigationAction?

    var body: some View {
        NavigationStack {
            WebViewContainer(
                url: currentURL,
                action: $navigationAction,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                isLoading: $isLoading,
                pageTitle: $pageTitle,
                displayedURLString: $urlString
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(pageTitle.isEmpty ? "Browser" : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) { addressBar }
            .toolbar { ToolbarItemGroup(placement: .bottomBar) { bottomBar } }
        }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Search or enter website name", text: $urlString)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { navigate() }
            if !urlString.isEmpty {
                Button {
                    urlString = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 6)
        .background(.bar)
    }

    @ViewBuilder
    private var bottomBar: some View {
        Button { navigationAction = .goBack } label: { Image(systemName: "chevron.left") }
            .disabled(!canGoBack)
        Button { navigationAction = .goForward } label: { Image(systemName: "chevron.right") }
            .disabled(!canGoForward)
        Spacer()
        if isLoading {
            ProgressView()
        } else {
            Button { navigationAction = .reload } label: { Image(systemName: "arrow.clockwise") }
        }
        Spacer()
        Button { navigationAction = .download } label: { Image(systemName: "arrow.down.circle") }
            .disabled(currentURL == nil)
    }

    private func navigate() {
        var trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !trimmed.contains("://") {
            if trimmed.contains("."), !trimmed.contains(" ") {
                trimmed = "https://\(trimmed)"
            } else {
                let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
                trimmed = "https://www.google.com/search?q=\(query)"
            }
        }
        currentURL = URL(string: trimmed)
    }
}

private enum WebViewNavigationAction {
    case goBack, goForward, reload, download
}

private struct WebViewContainer: UIViewRepresentable {
    let url: URL?
    @Binding var action: WebViewNavigationAction?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var displayedURLString: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.observe(webView)
        context.coordinator.loadIfNeeded(webView, url: url)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.loadIfNeeded(webView, url: url)

        guard let action else { return }
        switch action {
        case .goBack: webView.goBack()
        case .goForward: webView.goForward()
        case .reload: webView.reload()
        case .download:
            if let currentURL = webView.url {
                DownloadEngine.shared.startDownload(from: currentURL, suggestedName: webView.title)
            }
        }
        DispatchQueue.main.async { self.action = nil }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewContainer
        private var observations: [NSKeyValueObservation] = []
        private var lastRequestedURL: URL?

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func loadIfNeeded(_ webView: WKWebView, url: URL?) {
            guard let url, url != lastRequestedURL else { return }
            lastRequestedURL = url
            webView.load(URLRequest(url: url))
        }

        func observe(_ webView: WKWebView) {
            observations = [
                webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                    self?.parent.canGoBack = webView.canGoBack
                },
                webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                    self?.parent.canGoForward = webView.canGoForward
                },
                webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                    self?.parent.isLoading = webView.isLoading
                },
                webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                    self?.parent.pageTitle = webView.title ?? ""
                },
                webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                    if let urlString = webView.url?.absoluteString {
                        self?.parent.displayedURLString = urlString
                    }
                },
            ]
        }

        // MARK: WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            guard let url = navigationResponse.response.url else {
                decisionHandler(.allow)
                return
            }
            if !navigationResponse.canShowMIMEType {
                decisionHandler(.cancel)
                let suggestedName = navigationResponse.response.suggestedFilename
                DispatchQueue.main.async {
                    DownloadEngine.shared.startDownload(from: url, suggestedName: suggestedName)
                }
                return
            }
            decisionHandler(.allow)
        }

        // MARK: WKUIDelegate

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Links that try to open a new window/tab (target="_blank") just navigate
            // the same view — this browser is single-tab by design.
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

#Preview {
    BrowserView()
}
