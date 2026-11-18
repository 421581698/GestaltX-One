import Foundation
import Network
import UserNotifications
import UIKit

@MainActor
final class NativePairingCoordinator: ObservableObject {
    enum State {
        case idle
        case advertising
        case awaitingApproval
        case paired
        case failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var pin: String?
    @Published private(set) var pairedDevice: NativePairingMetadata?
    @Published private(set) var errorMessage: String?

    private let store = NativePairingRecordStore()
    private let advertiser = PairableHostAdvertiser()
    private var pairingTask: Task<Void, Never>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var isBusy: Bool {
        state == .advertising || state == .awaitingApproval
    }

    func refresh() async {
        do {
            pairedDevice = try await store.load()
            state = pairedDevice == nil ? .idle : .paired
        } catch {
            errorMessage = "Saved pairing data could not be verified: \(error.localizedDescription)"
            state = .failed
        }
    }

    func beginPairing(developerModeConfirmed: Bool) {
        guard developerModeConfirmed else {
            errorMessage = "Confirm that Developer Mode is enabled in iOS Settings first."
            return
        }
        guard GXDeviceConsoleRuntime.isLinked else {
            errorMessage = "The native device console is not linked in this build."
            return
        }
        guard !isBusy, pairedDevice == nil else { return }

        errorMessage = nil
        pin = nil
        state = .advertising
        beginBackgroundLease()

        pairingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let destination = try await store.preparePairingDestination()
                let outcome = try await DeviceConsole.shared.runPairing(
                    bindAddr: "0.0.0.0",
                    port: 0,
                    name: "GestaltX One",
                    model: UIDevice.current.model,
                    outPath: destination.path,
                    altIRKHex: "",
                    ready: { [weak self] serviceID, port, txt in
                        Task { @MainActor in
                            self?.advertiser.publish(port: port, serviceID: serviceID, txt: txt)
                        }
                    },
                    pin: { [weak self] value in
                        Task { @MainActor in
                            self?.pin = PairingNotifier.formatted(value)
                            self?.state = .awaitingApproval
                            await self?.notifyPairingCode(value)
                        }
                    }
                )
                let metadata = NativePairingMetadata(
                    deviceName: outcome.deviceName,
                    deviceModel: outcome.deviceModel,
                    deviceUDID: outcome.deviceUDID,
                    hostAltIRKHex: outcome.hostAltIRKHex,
                    pairedAt: Date()
                )
                try await store.saveSuccessfulPairing(metadata)
                pairedDevice = metadata
                pin = nil
                state = .paired
                await clearPairingNotification()
            } catch is CancellationError {
                state = .idle
            } catch {
                errorMessage = error.localizedDescription
                state = .failed
            }
            advertiser.stop()
            endBackgroundLease()
            pairingTask = nil
        }
    }

    func cancel() {
        DeviceConsole.shared.cancelCurrent()
        pairingTask?.cancel()
        advertiser.stop()
        pin = nil
        state = .idle
        Task { await clearPairingNotification() }
        endBackgroundLease()
    }

    func clearPairing() async {
        cancel()
        do {
            try await store.clear()
            pairedDevice = nil
            errorMessage = nil
            state = .idle
        } catch {
            errorMessage = "The pairing record could not be removed: \(error.localizedDescription)"
            state = .failed
        }
    }

    private func beginBackgroundLease() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "GestaltXOne.Pairing") { [weak self] in
            self?.cancel()
        }
    }

    private func endBackgroundLease() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func notifyPairingCode(_ code: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        let updated = await center.notificationSettings()
        guard updated.authorizationStatus == .authorized || updated.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "GestaltX One pairing code"
        content.body = "\(PairingNotifier.formatted(code)) — enter this code in iOS Settings to finish pairing."
        content.sound = .default
        content.threadIdentifier = "gestaltxone.pairing"
        try? await center.add(UNNotificationRequest(
            identifier: "gestaltxone.pairing.code",
            content: content,
            trigger: nil
        ))
    }

    private func clearPairingNotification() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["gestaltxone.pairing.code"])
        center.removeDeliveredNotifications(withIdentifiers: ["gestaltxone.pairing.code"])
    }
}
