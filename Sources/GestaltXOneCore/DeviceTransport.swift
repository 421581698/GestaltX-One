import Foundation

/// Readiness reported by the native host. These values describe prerequisites;
/// the app must never attempt to bypass an unavailable system permission.
public struct PairingReadiness: Codable, Sendable, Equatable {
    public let developerModeEnabled: Bool
    public let localDevelopmentTunnelReady: Bool
    public let localNetworkPermissionGranted: Bool

    public init(
        developerModeEnabled: Bool,
        localDevelopmentTunnelReady: Bool,
        localNetworkPermissionGranted: Bool
    ) {
        self.developerModeEnabled = developerModeEnabled
        self.localDevelopmentTunnelReady = localDevelopmentTunnelReady
        self.localNetworkPermissionGranted = localNetworkPermissionGranted
    }

    public var canAttemptPairing: Bool {
        developerModeEnabled && localDevelopmentTunnelReady && localNetworkPermissionGranted
    }

    public var missingRequirements: [String] {
        var missing: [String] = []
        if !developerModeEnabled { missing.append("Developer Mode is not enabled") }
        if !localDevelopmentTunnelReady { missing.append("The local development tunnel is not ready") }
        if !localNetworkPermissionGranted { missing.append("Local Network permission has not been granted") }
        return missing
    }
}

public enum PairingState: String, Codable, Sendable {
    case unavailable
    case notPaired = "not_paired"
    case preparing
    case awaitingSystemApproval = "awaiting_system_approval"
    case paired
    case failed
}

public struct PairingSnapshot: Codable, Sendable, Equatable {
    public let state: PairingState
    public let readiness: PairingReadiness
    public let detail: String?

    public init(state: PairingState, readiness: PairingReadiness, detail: String? = nil) {
        self.state = state
        self.readiness = readiness
        self.detail = detail
    }
}

/// Device transport boundary. A production implementation must use Apple's
/// supported local pairing flow and surface every required user/system prompt.
public protocol DeviceTransport: DeviceAdapting {
    func pairingStatus() async -> PairingSnapshot
    func requestPairingAfterUserInitiation() async throws -> PairingSnapshot
}

public enum DeviceTransportError: Error, Equatable {
    case unavailable
    case prerequisitesMissing([String])
}

/// Safe placeholder used until the iOS DeviceConsole/RSD transport is integrated.
/// It intentionally performs no network discovery, pairing, or system changes.
public struct UnavailableDeviceTransport: DeviceTransport {
    public init() {}

    public func snapshot() async -> DeviceSnapshot {
        await SystemDeviceAdapter().snapshot()
    }

    public func capabilities() async -> CapabilitySnapshot {
        .baseline
    }

    public func pairingStatus() async -> PairingSnapshot {
        PairingSnapshot(
            state: .unavailable,
            readiness: PairingReadiness(
                developerModeEnabled: false,
                localDevelopmentTunnelReady: false,
                localNetworkPermissionGranted: false
            ),
            detail: "The native device transport has not been integrated."
        )
    }

    public func requestPairingAfterUserInitiation() async throws -> PairingSnapshot {
        throw DeviceTransportError.unavailable
    }
}
