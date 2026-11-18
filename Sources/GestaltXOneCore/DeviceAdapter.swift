import Foundation
#if canImport(Darwin)
import Darwin
#endif

public struct DeviceSnapshot: Codable, Sendable, Equatable {
    public let operatingSystem: String
    public let operatingSystemVersion: String
    public let deviceModelIdentifier: String
    public let processArchitecture: String
    public let isSimulator: Bool

    public init(
        operatingSystem: String,
        operatingSystemVersion: String,
        deviceModelIdentifier: String,
        processArchitecture: String,
        isSimulator: Bool
    ) {
        self.operatingSystem = operatingSystem
        self.operatingSystemVersion = operatingSystemVersion
        self.deviceModelIdentifier = deviceModelIdentifier
        self.processArchitecture = processArchitecture
        self.isSimulator = isSimulator
    }
}

public struct CapabilitySnapshot: Codable, Sendable, Equatable {
    public let nativeHostAvailable: Bool
    public let deviceInfoAvailable: Bool
    public let localBackupAvailable: Bool
    public let mobileGestaltReadAvailable: Bool
    public let mobileGestaltWriteAvailable: Bool
    public let devicePairingAvailable: Bool
    public let notes: [String]

    public static let baseline = CapabilitySnapshot(
        nativeHostAvailable: true,
        deviceInfoAvailable: true,
        localBackupAvailable: true,
        mobileGestaltReadAvailable: false,
        mobileGestaltWriteAvailable: false,
        devicePairingAvailable: false,
        notes: [
            "MobileGestalt access is not implemented by this foundation package.",
            "Pairing requires a separately integrated and user-authorized iOS transport.",
            "A web page opened in Safari does not have native host privileges."
        ]
    )
}

public protocol DeviceAdapting: Sendable {
    func snapshot() async -> DeviceSnapshot
    func capabilities() async -> CapabilitySnapshot
}

public struct SystemDeviceAdapter: DeviceAdapting {
    public init() {}

    public func snapshot() async -> DeviceSnapshot {
        let process = ProcessInfo.processInfo
        #if os(iOS)
        let operatingSystem = "iOS"
        #elseif os(macOS)
        let operatingSystem = "macOS"
        #else
        let operatingSystem = "Unknown"
        #endif

        #if targetEnvironment(simulator)
        let simulator = true
        #else
        let simulator = false
        #endif

        #if os(iOS)
        let modelIdentifier = Self.machineIdentifier()
        #else
        let modelIdentifier = "not-available-on-this-platform"
        #endif

        return DeviceSnapshot(
            operatingSystem: operatingSystem,
            operatingSystemVersion: process.operatingSystemVersionString,
            deviceModelIdentifier: modelIdentifier,
            processArchitecture: "not-exposed-by-portable-adapter",
            isSimulator: simulator
        )
    }

    public func capabilities() async -> CapabilitySnapshot {
        .baseline
    }

    #if os(iOS) && canImport(Darwin)
    private static func machineIdentifier() -> String {
        var size = 0
        guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0, size > 0 else {
            return "unknown"
        }
        var machine = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.machine", &machine, &size, nil, 0) == 0 else {
            return "unknown"
        }
        return String(cString: machine)
    }
    #endif
}
