import Foundation
import WebKit
import GestaltXOneCore

@MainActor
final class GestaltXNativeMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    private let expectedHost: String
    let session: BridgeSession
    private let deviceTransport = UnavailableDeviceTransport()
    private let taskRuntime = TaskRuntime()
    private let backupStore: BackupStore

    init(expectedHost: String, backupDirectory: URL) {
        self.expectedHost = expectedHost.lowercased()
        self.session = BridgeSession()
        self.backupStore = BackupStore(directory: backupDirectory)
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping (Any?, String?) -> Void
    ) {
        let origin = message.frameInfo.securityOrigin
        guard message.name == "gestaltx",
              message.frameInfo.isMainFrame,
              origin.protocol == "https",
              origin.port == 443,
              origin.host.lowercased() == expectedHost else {
            replyHandler(nil, "Untrusted bridge origin")
            return
        }

        guard let body = message.body as? [String: Any],
              JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body),
              data.count <= 65_536,
              let request = try? JSONDecoder().decode(BridgeRequest.self, from: data) else {
            replyHandler(nil, "Invalid bridge request")
            return
        }

        Task { @MainActor in
            guard await session.validateAndConsume(request) else {
                replyHandler(encode(.rejected(request.requestID, reason: "Invalid session or replayed request")), nil)
                return
            }

            do {
                let response = try await dispatch(request)
                replyHandler(encode(response), nil)
            } catch {
                replyHandler(encode(BridgeResponse(
                    requestID: request.requestID,
                    success: false,
                    status: "failed",
                    error: String(describing: error)
                )), nil)
            }
        }
    }

    private func dispatch(_ request: BridgeRequest) async throws -> BridgeResponse {
        switch request.action {
        case .deviceGetInfo:
            let snapshot = await deviceTransport.snapshot()
            return BridgeResponse(
                requestID: request.requestID,
                success: true,
                status: "completed",
                data: [
                    "operatingSystem": snapshot.operatingSystem,
                    "operatingSystemVersion": snapshot.operatingSystemVersion,
                    "deviceModelIdentifier": snapshot.deviceModelIdentifier,
                    "isSimulator": String(snapshot.isSimulator)
                ]
            )

        case .deviceGetCapabilities:
            let value = await deviceTransport.capabilities()
            return BridgeResponse(
                requestID: request.requestID,
                success: true,
                status: "completed",
                data: [
                    "nativeHostAvailable": String(value.nativeHostAvailable),
                    "deviceInfoAvailable": String(value.deviceInfoAvailable),
                    "localBackupAvailable": String(value.localBackupAvailable),
                    "mobileGestaltReadAvailable": String(value.mobileGestaltReadAvailable),
                    "mobileGestaltWriteAvailable": String(value.mobileGestaltWriteAvailable),
                    "devicePairingAvailable": String(value.devicePairingAvailable),
                    "nativeDeviceConsoleLinked": String(GXDeviceConsoleRuntime.isLinked),
                    "notes": value.notes.joined(separator: " | ")
                ]
            )

        case .deviceGetPairingStatus:
            let pairing = await deviceTransport.pairingStatus()
            return BridgeResponse(
                requestID: request.requestID,
                success: true,
                status: pairing.state.rawValue,
                data: [
                    "developerModeEnabled": String(pairing.readiness.developerModeEnabled),
                    "localDevelopmentTunnelReady": String(pairing.readiness.localDevelopmentTunnelReady),
                    "localNetworkPermissionGranted": String(pairing.readiness.localNetworkPermissionGranted),
                    "canAttemptPairing": String(pairing.readiness.canAttemptPairing),
                    "canOpenDeviceSession": String(pairing.readiness.canOpenDeviceSession),
                    "missingPairingRequirements": pairing.readiness.missingPairingRequirements.joined(separator: " | "),
                    "missingSessionRequirements": pairing.readiness.missingSessionRequirements.joined(separator: " | "),
                    "detail": pairing.detail ?? ""
                ]
            )

        case .backupGetStatus:
            let exists = await backupStore.backupDirectoryExists()
            return BridgeResponse(
                requestID: request.requestID,
                success: true,
                status: "completed",
                data: ["directoryInitialized": String(exists)]
            )

        case .taskGetStatus:
            guard let rawID = request.payload["taskID"], let id = UUID(uuidString: rawID) else {
                return .rejected(request.requestID, reason: "A valid taskID is required")
            }
            guard let snapshot = await taskRuntime.snapshot(id) else {
                return .rejected(request.requestID, reason: "Task not found")
            }
            return BridgeResponse(
                requestID: request.requestID,
                success: true,
                status: snapshot.state.rawValue,
                data: ["eventCount": String(snapshot.events.count)]
            )
        }
    }

    private func encode(_ response: BridgeResponse) -> Any? {
        guard let data = try? JSONEncoder().encode(response),
              let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return object
    }
}
