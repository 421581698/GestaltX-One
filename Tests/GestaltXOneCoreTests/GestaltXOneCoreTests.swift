import XCTest
@testable import GestaltXOneCore

final class GestaltXOneCoreTests: XCTestCase {
    func testBridgeSessionRejectsReplayAndWrongNonce() async {
        let session = BridgeSession()
        let request = BridgeRequest(action: .deviceGetInfo, nonce: await session.nonce)
        XCTAssertTrue(await session.validateAndConsume(request))
        XCTAssertFalse(await session.validateAndConsume(request))

        let forged = BridgeRequest(action: .deviceGetInfo, nonce: "wrong")
        XCTAssertFalse(await session.validateAndConsume(forged))
    }

    func testTaskRuntimeEnforcesLifecycle() async throws {
        let runtime = TaskRuntime()
        let id = await runtime.createTask()
        try await runtime.transition(id, to: .checking, message: "Checking host")
        try await runtime.transition(id, to: .running, message: "Read-only inspection")
        try await runtime.transition(id, to: .verifying, message: "Verifying response")
        try await runtime.transition(id, to: .completed, message: "Done")

        let snapshot = await runtime.snapshot(id)
        XCTAssertEqual(snapshot?.state, .completed)
        XCTAssertEqual(snapshot?.events.count, 5)

        do {
            try await runtime.transition(id, to: .running, message: "Invalid restart")
            XCTFail("Expected terminal task rejection")
        } catch let error as TaskRuntimeError {
            XCTAssertEqual(error, .terminalTask)
        }
    }

    func testBackupIntegrity() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = BackupStore(directory: directory)
        let receipt = try await store.createBackup(data: Data("sample".utf8), name: "device-config")
        XCTAssertTrue(try await store.verifyBackup(receipt))
    }

    func testUnsafeBackupNameIsRejected() async {
        let directory = FileManager.default.temporaryDirectory
        let store = BackupStore(directory: directory)
        do {
            _ = try await store.createBackup(data: Data(), name: "../escape")
            XCTFail("Expected unsafe name rejection")
        } catch {
            XCTAssertTrue(error is BackupStoreError)
        }
    }

    func testMobileGestaltIsNotFalselyAdvertised() async {
        let capabilities = await SystemDeviceAdapter().capabilities()
        XCTAssertFalse(capabilities.mobileGestaltReadAvailable)
        XCTAssertFalse(capabilities.mobileGestaltWriteAvailable)
        XCTAssertFalse(capabilities.devicePairingAvailable)
    }
}
