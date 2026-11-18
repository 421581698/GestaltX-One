import XCTest
@testable import GestaltXOneCore

final class DeviceTransportTests: XCTestCase {
    func testPairingDoesNotRequireTheLaterRSDTunnel() {
        let readiness = PairingReadiness(
            developerModeEnabled: true,
            localDevelopmentTunnelReady: false,
            localNetworkPermissionGranted: true
        )

        XCTAssertTrue(readiness.canAttemptPairing)
        XCTAssertFalse(readiness.canOpenDeviceSession)
        XCTAssertTrue(readiness.missingPairingRequirements.isEmpty)
        XCTAssertEqual(readiness.missingSessionRequirements, ["The local development tunnel is not ready"])
    }

    func testPairingRequiresDeveloperModeAndLocalNetworkPermission() {
        let readiness = PairingReadiness(
            developerModeEnabled: true,
            localDevelopmentTunnelReady: true,
            localNetworkPermissionGranted: false
        )

        XCTAssertFalse(readiness.canAttemptPairing)
        XCTAssertFalse(readiness.missingPairingRequirements.isEmpty)
    }

    func testUnavailableTransportDoesNotPretendPairingWorks() async {
        let transport = UnavailableDeviceTransport()
        let snapshot = await transport.pairingStatus()

        XCTAssertEqual(snapshot.state, .unavailable)
        XCTAssertFalse(snapshot.readiness.canAttemptPairing)

        do {
            _ = try await transport.requestPairingAfterUserInitiation()
            XCTFail("Unavailable transport must not start pairing")
        } catch let error as DeviceTransportError {
            XCTAssertEqual(error, .unavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
