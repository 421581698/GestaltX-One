import Foundation

struct NativePairingMetadata: Codable, Sendable, Equatable {
    let deviceName: String
    let deviceModel: String
    let deviceUDID: String
    let hostAltIRKHex: String
    let pairedAt: Date
}

/// Stores the native pairing plist and its small metadata index in the app's
/// private Application Support directory. Credentials are never placed in
/// Documents, iCloud, a shared app group, or the web control plane.
actor NativePairingRecordStore {
    private struct Index: Codable {
        let version: Int
        let metadata: NativePairingMetadata
    }

    private let directory: URL
    private let nativeRecordURL: URL
    private let indexURL: URL
    private let fileManager: FileManager
    private let maximumPairingFileSize = 1_048_576
    private let maximumIndexSize = 65_536

    init(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        let root = rootDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = root.appendingPathComponent("GestaltXOne", isDirectory: true)
        let nativeDirectory = directory.appendingPathComponent("Native", isDirectory: true)
        nativeRecordURL = nativeDirectory.appendingPathComponent("device-pairing.plist")
        indexURL = directory.appendingPathComponent("PairingIndex.plist")
    }

    /// Prepare the fixed destination passed to the C pairing API.
    /// A previous record is not overwritten implicitly.
    func preparePairingDestination() throws -> URL {
        try ensurePrivateDirectories()
        if fileManager.fileExists(atPath: indexURL.path) {
            throw StoreError.existingPairingRecord
        }
        if fileManager.fileExists(atPath: nativeRecordURL.path) {
            // A failed earlier handshake may leave a partial file without a
            // committed metadata index. Remove only a bounded regular file;
            // never follow or delete a symlink supplied at this fixed path.
            try validateRegularFile(nativeRecordURL, maximumSize: maximumPairingFileSize)
            try fileManager.removeItem(at: nativeRecordURL)
        }
        return nativeRecordURL
    }

    /// Commit metadata only after the native pairing API reports success and
    /// the resulting pairing plist passes basic structural and filesystem checks.
    func saveSuccessfulPairing(_ metadata: NativePairingMetadata) throws {
        try validate(metadata)
        try validatePairingFile()
        try protect(nativeRecordURL, excludedFromBackup: true)

        let data = try PropertyListEncoder().encode(Index(version: 1, metadata: metadata))
        guard data.count <= maximumIndexSize else { throw StoreError.invalidIndex }
        try data.write(to: indexURL, options: [.atomic, .completeFileProtection])
        try protect(indexURL, excludedFromBackup: true)
    }

    func load() throws -> NativePairingMetadata? {
        guard fileManager.fileExists(atPath: indexURL.path) else { return nil }
        try validateRegularFile(indexURL, maximumSize: maximumIndexSize)
        let data = try Data(contentsOf: indexURL, options: [.mappedIfSafe])
        let index = try PropertyListDecoder().decode(Index.self, from: data)
        guard index.version == 1 else { throw StoreError.unsupportedVersion }
        try validate(index.metadata)
        try validatePairingFile()
        return index.metadata
    }

    /// Delete the credential file before its metadata index.
    func clear() throws {
        if fileManager.fileExists(atPath: nativeRecordURL.path) {
            try validateRegularFile(nativeRecordURL, maximumSize: maximumPairingFileSize)
            try fileManager.removeItem(at: nativeRecordURL)
        }
        if fileManager.fileExists(atPath: indexURL.path) {
            try validateRegularFile(indexURL, maximumSize: maximumIndexSize)
            try fileManager.removeItem(at: indexURL)
        }
    }

    private func ensurePrivateDirectories() throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        let nativeDirectory = nativeRecordURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: nativeDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        try protect(directory, excludedFromBackup: true)
        try protect(nativeDirectory, excludedFromBackup: true)
    }

    private func protect(_ url: URL, excludedFromBackup: Bool) throws {
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = excludedFromBackup
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    private func validatePairingFile() throws {
        try validateRegularFile(nativeRecordURL, maximumSize: maximumPairingFileSize)
        let data = try Data(contentsOf: nativeRecordURL, options: [.mappedIfSafe])
        _ = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    }

    private func validateRegularFile(_ url: URL, maximumSize: Int) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isSymbolicLink != true,
              values.isRegularFile == true,
              let size = values.fileSize,
              size > 0,
              size <= maximumSize else {
            throw StoreError.invalidFile
        }
    }

    private func validate(_ metadata: NativePairingMetadata) throws {
        guard !metadata.deviceName.isEmpty,
              metadata.deviceName.utf8.count <= 256,
              !metadata.deviceModel.isEmpty,
              metadata.deviceModel.utf8.count <= 256,
              !metadata.deviceUDID.isEmpty,
              metadata.deviceUDID.utf8.count <= 128,
              metadata.hostAltIRKHex.utf8.count <= 128,
              metadata.hostAltIRKHex.allSatisfy({ $0.isHexDigit }) else {
            throw StoreError.invalidMetadata
        }
    }

    enum StoreError: Error, Equatable {
        case existingPairingRecord
        case invalidFile
        case invalidIndex
        case invalidMetadata
        case unsupportedVersion
    }
}
