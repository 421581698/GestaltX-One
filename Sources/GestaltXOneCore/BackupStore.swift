import Foundation
import CryptoKit

public struct BackupReceipt: Codable, Sendable, Equatable {
    public let identifier: UUID
    public let fileName: String
    public let byteCount: Int
    public let sha256: String
    public let createdAt: Date
}

public enum BackupStoreError: Error {
    case invalidName
    case integrityCheckFailed
}

public actor BackupStore {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    public func createBackup(data: Data, name: String) throws -> BackupReceipt {
        let safeName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeName.isEmpty,
              safeName.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$"#, options: .regularExpression) != nil
        else { throw BackupStoreError.invalidName }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let identifier = UUID()
        let fileName = "(safeName)-(identifier.uuidString).backup"
        let destination = directory.appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: destination, options: [.atomic, .completeFileProtectionUnlessOpen])

        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return BackupReceipt(
            identifier: identifier,
            fileName: fileName,
            byteCount: data.count,
            sha256: digest,
            createdAt: .now
        )
    }

    public func verifyBackup(_ receipt: BackupReceipt) throws -> Bool {
        let url = directory.appendingPathComponent(receipt.fileName, isDirectory: false)
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == receipt.byteCount, digest == receipt.sha256 else {
            throw BackupStoreError.integrityCheckFailed
        }
        return true
    }

    public func backupDirectoryExists() -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
