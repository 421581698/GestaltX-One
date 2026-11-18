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

    /// Pairing advertises a local host and requires Developer Mode plus Local Network permission.
    /// The RSD tunnel is a later connection prerequisite, not a pairing prerequisite.
    public var canAttemptPairing: Bool {
        developerModeEnabled && localNetworkPermissionGranted
    }

    public var canOpenDeviceSession: Bool {
        canAttemptPairing && localDevelopmentTunnelReady
    }

    public var missingPairingRequirements: [String] {
        var missing: [String] = []
        if !developerModeEnabled { missing.append("Developer Mode has not been confirmed") }
        if !localNetworkPermissionGranted { missing.append("Local Network permission has not been granted") }
        return missing
    }

    public var missingSessionRequirements: [String] {
        var missing = missingPairingRequirements
        if !localDevelopmentTunnelReady { missing.append("The local development tunnel is not ready") }
        return missing
    }

    /// Compatibility name for callers displaying pairing prerequisites.
    public var missingRequirements: [String] { missingPairingRequirements }
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
