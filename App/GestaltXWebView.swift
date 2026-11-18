import SwiftUI
import WebKit
import GestaltXOneCore

@MainActor
public struct GestaltXWebView: UIViewRepresentable {
    public let url: URL
    public let allowedHost: String

    public init(url: URL, allowedHost: String) {
        self.url = url
        self.allowedHost = allowedHost.lowercased()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(allowedHost: allowedHost)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        let backupDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("GestaltXOne/Backups", isDirectory: true)

        let bridge = GestaltXNativeMessageHandler(
            expectedHost: allowedHost,
            backupDirectory: backupDirectory
        )
        contentController.addScriptMessageHandler(bridge, contentWorld: .page, name: "gestaltx")

        let nonceScript = "window.__GESTALTX_BRIDGE_NONCE__ = '\(bridge.session.nonce)';"
        contentController.addUserScript(WKUserScript(
            source: nonceScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == allowedHost else {
            return webView
        }
        webView.load(URLRequest(url: url))
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    @MainActor
    public final class Coordinator: NSObject, WKNavigationDelegate {
        private let allowedHost: String

        init(allowedHost: String) {
            self.allowedHost = allowedHost
        }

        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let target = navigationAction.request.url,
                  target.scheme?.lowercased() == "https",
                  target.host?.lowercased() == allowedHost else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
