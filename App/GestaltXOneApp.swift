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
    @State private var showingPairing = false

    private var controlPlaneURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "GESTALTX_CONTROL_PLANE_URL") as? String,
              let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
    }

    var body: some View {
        Group {
            if let url = controlPlaneURL, let host = url.host {
                GestaltXWebView(url: url, allowedHost: host)
                    .ignoresSafeArea()
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            showingPairing = true
                        } label: {
                            Label("设备配对", systemImage: "link")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.regularMaterial, in: Capsule())
                        }
                        .padding()
                    }
                    .sheet(isPresented: $showingPairing) {
                        NativePairingView()
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "network.slash")
                        .font(.largeTitle)
                    Text("控制中心尚未配置")
                        .font(.headline)
                    Text("先完成原生设备配对。网页控制中心需要配置 HTTPS 域名后才能启用。")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    NativePairingView()
                }
                .padding()
            }
        }
    }
}
