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
              url.host != nil,
              url.host != "configure-your-domain.example" else { return nil }
        return url
    }

    var body: some View {
        TabView {
            NativePairingView()
                .tabItem {
                    Label("Device", systemImage: "iphone")
                }

            if let url = controlPlaneURL, let host = url.host {
                GestaltXWebView(url: url, allowedHost: host)
                    .tabItem {
                        Label("Tasks", systemImage: "square.grid.2x2")
                    }
            }
        }
    }
}

@MainActor
private struct NativePairingView: View {
    @StateObject private var pairing = NativePairingCoordinator()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("GestaltX One")
                            .font(.largeTitle.bold())
                        Text("Secure device pairing")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(
                                GXDeviceConsoleRuntime.isLinked ? "Native transport linked" : "Native transport unavailable",
                                systemImage: GXDeviceConsoleRuntime.isLinked ? "checkmark.circle.fill" : "xmark.circle"
                            )
                            .foregroundStyle(GXDeviceConsoleRuntime.isLinked ? .green : .secondary)

                            Text("Pairing uses the iOS Developer Mode pairing flow. It does not bypass Apple's system permissions.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Before pairing") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("1. Start pairing here to advertise the temporary pairing host.")
                            Text("2. Open Settings → Privacy & Security → Developer Mode.")
                            Text("3. Tap Pair with GestaltX and enter the six-digit code shown below.")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Pairing status") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(pairing.state.title, systemImage: pairing.state.symbol)
                                .font(.headline)
                            if let metadata = pairing.pairedDevice {
                                Text("Paired: \(metadata.deviceName) · \(metadata.deviceModel)")
                                    .font(.footnote)
                            }
                            if let pin = pairing.pin {
                                Text("Pairing code")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(pin)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .textSelection(.enabled)
                            }
                            if let error = pairing.errorMessage {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        Button {
                            pairing.beginPairing()
                        } label: {
                            Label("Start pairing", systemImage: "link")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!GXDeviceConsoleRuntime.isLinked || pairing.isBusy || pairing.pairedDevice != nil)

                        if pairing.isBusy {
                            Button(role: .destructive) {
                                pairing.cancel()
                            } label: {
                                Image(systemName: "stop.circle")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if pairing.pairedDevice != nil {
                        Button(role: .destructive) {
                            Task { await pairing.clearPairing() }
                        } label: {
                            Label("Remove pairing record", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("The pairing code is temporary. Keep this app open while switching to Settings. iOS may suspend background work; if pairing stops, return here and retry. GestaltX One does not bypass Developer Mode or system confirmation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Device")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await pairing.refresh()
            }
        }
    }


}

private extension NativePairingCoordinator.State {
    var title: String {
        switch self {
        case .idle: "Not paired"
        case .advertising: "Waiting for iOS pairing"
        case .awaitingApproval: "Enter the pairing code in Settings"
        case .cancelling: "Cancelling pairing…"
        case .paired: "Paired"
        case .failed: "Pairing failed"
        }
    }

    var symbol: String {
        switch self {
        case .idle: "circle"
        case .advertising: "dot.radiowaves.left.and.right"
        case .awaitingApproval: "number.circle"
        case .cancelling: "stop.circle"
        case .paired: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle"
        }
    }
}
