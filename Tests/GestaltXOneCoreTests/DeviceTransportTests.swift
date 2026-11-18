import XCTest
@testable import GestaltXOneCore

final class DeviceTransportTests: XCTestCase {
    func testPairingRequiresEverySystemPrerequisite() {
        let readiness = PairingReadiness(
            developerModeEnabled: true,
            localDevelopmentTunnelReady: true,
            localNetworkPermissionGranted: false
        )

        XCTAssertFalse(readiness.canAttemptPairing)
        XCTAssertEqual(readiness.missingRequirements, ["Local Network permission has not been granted"])
    }

    func testPairingBecomesReadyOnlyWhenAllPrerequisitesArePresent() {
        let readiness = PairingReadiness(
            developerModeEnabled: true,
            localDevelopmentTunnelReady: true,
            localNetworkPermissionGranted: true
        )

        XCTAssertTrue(readiness.canAttemptPairing)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
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
