import Combine
import Foundation
import UIKit

@MainActor
final class NativePairingCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case advertising
        case awaitingPin
        case paired
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var pin: String?
    @Published private(set) var pairedDevice: NativePairingMetadata?

    private let store = NativePairingRecordStore()
    private let advertiser = PairableHostAdvertiser()
    private var pairingTask: Task<Void, Never>?

    var isBusy: Bool { pairingTask != nil }

    func refresh() {
        Task {
            do {
                pairedDevice = try await store.load()
                if pairedDevice != nil { state = .paired }
            } catch {
                state = .failed("Saved pairing data could not be verified: \\(error.localizedDescription)")
            }
        }
    }

    /// Starts pairing only after an explicit native button tap.
    func startPairing() {
        guard pairingTask == nil, pairedDevice == nil else { return }
        state = .preparing
        pin = nil

        pairingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let destination = try await store.preparePairingDestination()
                let previous = try await store.load()
                let outcome = try await DeviceConsole.shared.runPairing(
                    bindAddr: "0.0.0.0",
                    port: 0,
                    name: "GestaltX One",
                    model: UIDevice.current.model,
                    outPath: destination.path,
                    altIRKHex: previous?.hostAltIRKHex ?? "",
                    ready: { [weak self] serviceID, port, txt in
                        Task { @MainActor in
                            self?.advertiser.publish(port: port, serviceID: serviceID, txt: txt)
                            self?.state = .advertising
                        }
                    },
                    pin: { [weak self] value in
                        Task { @MainActor in
                            self?.pin = value
                            self?.state = .awaitingPin
                        }
                    }
                )

                let returnedPath = URL(fileURLWithPath: outcome.pairingFilePath).standardizedFileURL
                guard returnedPath == destination.standardizedFileURL else {
                    throw NativePairingError.unexpectedPairingPath
                }

                let metadata = NativePairingMetadata(
                    deviceName: outcome.deviceName,
                    deviceModel: outcome.deviceModel,
                    deviceUDID: outcome.deviceUDID,
                    hostAltIRKHex: outcome.hostAltIRKHex,
                    pairedAt: Date()
                )
                try await store.saveSuccessfulPairing(metadata)
                pairedDevice = metadata
                state = .paired
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .failed(error.localizedDescription)
            }

            advertiser.stop()
            pin = nil
            pairingTask = nil
        }
    }

    func cancel() {
        DeviceConsole.shared.cancelCurrent()
        pairingTask?.cancel()
        advertiser.stop()
    }

    func clearPairing() {
        guard pairingTask == nil else { return }
        Task {
            do {
                try await store.clear()
                pairedDevice = nil
                pin = nil
                state = .idle
            } catch {
                state = .failed("Could not safely remove pairing data: \\(error.localizedDescription)")
            }
        }
    }
}

private enum NativePairingError: LocalizedError {
    case unexpectedPairingPath

    var errorDescription: String? {
        "The native pairing library returned an unexpected credential path."
    }
}

/// The upstream DeviceConsole wrapper uses this localization hook for its
/// fallback strings. GestaltX One currently ships the English source strings.
func L(_ value: String) -> String { value }
