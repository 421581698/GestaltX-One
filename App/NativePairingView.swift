import SwiftUI

struct NativePairingView: View {
    @StateObject private var coordinator = NativePairingCoordinator()

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 42))
                .foregroundStyle(.tint)

            Text("设备配对")
                .font(.title2.bold())

            statusView

            if let pin = coordinator.pin {
                VStack(spacing: 8) {
                    Text("系统配对验证码")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pin)
                        .font(.system(size: 32, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .textSelection(.enabled)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            if case .paired = coordinator.state, let device = coordinator.pairedDevice {
                VStack(spacing: 4) {
                    Text(device.deviceName).font(.headline)
                    Text(device.deviceModel).font(.caption).foregroundStyle(.secondary)
                }
                Button("清除本机配对记录", role: .destructive) {
                    coordinator.clearPairing()
                }
            } else {
                Button {
                    coordinator.startPairing()
                } label: {
                    Label("开始配对", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(coordinator.isBusy)

                if coordinator.isBusy {
                    Button("取消配对", role: .destructive) {
                        coordinator.cancel()
                    }
                }
            }

            Text("配对需要 iOS 系统权限。请按系统提示操作，并保持此页面打开。此流程不会绕过 Developer Mode 或系统授权。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .onAppear { coordinator.refresh() }
    }

    @ViewBuilder
    private var statusView: some View {
        switch coordinator.state {
        case .idle:
            Text("尚未配对").foregroundStyle(.secondary)
        case .preparing:
            ProgressView("正在准备配对服务…")
        case .advertising:
            ProgressView("正在广播配对服务，请按 iOS 系统提示继续…")
        case .awaitingPin:
            Text("等待你在系统界面确认验证码")
        case .paired:
            Label("设备已配对", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }
}
