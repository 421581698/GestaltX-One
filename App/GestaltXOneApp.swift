import SwiftUI

@main
struct GestaltXOneApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

private struct RootView: View {
    private var controlPlaneURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "GESTALTX_CONTROL_PLANE_URL") as? String,
              let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              let host = url.host else { return nil }
        return url
    }

    var body: some View {
        Group {
            if let url = controlPlaneURL, let host = url.host {
                GestaltXWebView(url: url, allowedHost: host)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "Control Center Not Configured",
                    systemImage: "network.slash",
                    description: Text("Set GESTALTX_CONTROL_PLANE_URL to your HTTPS control-center URL in the app build settings.")
                )
            }
        }
    }
}
