import XCTest
@testable import GestaltXOneCore

final class GestaltXOneCoreTests: XCTestCase {
    func testBridgeSessionRejectsReplayAndWrongNonce() async {
        let session = BridgeSession()
        let nonce = session.nonce
        let request = BridgeRequest(action: .deviceGetInfo, nonce: nonce)

        let firstAcceptance = await session.validateAndConsume(request)
        let replayAcceptance = await session.validateAndConsume(request)
        XCTAssertTrue(firstAcceptance)
        XCTAssertFalse(replayAcceptance)

        let forged = BridgeRequest(action: .deviceGetInfo, nonce: "wrong")
        let forgedAcceptance = await session.validateAndConsume(forged)
        XCTAssertFalse(forgedAcceptance)
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
        let verified = try await store.verifyBackup(receipt)
        XCTAssertTrue(verified)
    }

    func testBackupReceiptCannotEscapeStoreDirectory() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BackupStore(directory: directory)
        let valid = try await store.createBackup(data: Data("safe".utf8), name: "device")
        let forged = BackupReceipt(
            identifier: valid.identifier,
            fileName: "../outside.backup",
            byteCount: valid.byteCount,
            sha256: valid.sha256,
            createdAt: valid.createdAt
        )
        do {
            _ = try await store.verifyBackup(forged)
            XCTFail("A path-traversing receipt must be rejected")
        } catch let error as BackupStoreError {
            XCTAssertEqual(error, .invalidReceipt)
        }
    }

    func testBackupReceiptMustMatchItsIdentifier() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BackupStore(directory: directory)
        let valid = try await store.createBackup(data: Data("safe".utf8), name: "device")
        let forged = BackupReceipt(
            identifier: UUID(),
            fileName: valid.fileName,
            byteCount: valid.byteCount,
            sha256: valid.sha256,
            createdAt: valid.createdAt
        )
        do {
            _ = try await store.verifyBackup(forged)
            XCTFail("A receipt with a mismatched identifier must be rejected")
        } catch let error as BackupStoreError {
            XCTAssertEqual(error, .invalidReceipt)
        }
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
