import Foundation
import Combine
import UIKit

@MainActor
final class NativePairingCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case advertising
        case awaitingApproval
        case cancelling
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

    init() {
        advertiser.onFailure = { [weak self] message in
            guard let self, self.isBusy else { return }
            self.errorMessage = "Bonjour advertising failed: \(message)"
            self.cancel()
        }
    }

    var isBusy: Bool {
        state == .advertising || state == .awaitingApproval || state == .cancelling
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
                            self?.pin = Self.formattedPairingCode(value)
                            self?.state = .awaitingApproval
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
            } catch {
                if Task.isCancelled {
                    state = .idle
                } else {
                    errorMessage = error.localizedDescription
                    state = .failed
                }
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
        if isBusy { state = .cancelling }
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

    private static func formattedPairingCode(_ code: String) -> String {
        let digits = code.filter(\.isNumber)
        guard digits.count == 6 else { return code }
        let split = digits.index(digits.startIndex, offsetBy: 3)
        return "\(digits[..<split]) \(digits[split...])"
    }

}
