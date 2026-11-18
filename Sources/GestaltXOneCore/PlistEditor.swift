import Foundation
import CryptoKit
import CoreFoundation

/// A property-list value model that preserves the native plist value types.
public indirect enum PlistValue: Sendable, Equatable {
    case dictionary([String: PlistValue])
    case array([PlistValue])
    case string(String)
    case integer(Int64)
    case real(Double)
    case boolean(Bool)
    case data(Data)
    case date(Date)

    fileprivate static func decode(_ value: Any, depth: Int = 0) throws -> PlistValue {
        guard depth <= 64 else { throw PlistEditorError.maximumDepthExceeded }
        if let value = value as? String { return .string(value) }
        if let value = value as? Data { return .data(value) }
        if let value = value as? Date { return .date(value) }
        if let values = value as? [Any] {
            return .array(try values.map { try decode($0, depth: depth + 1) })
        }
        if let values = value as? [String: Any] {
            var result: [String: PlistValue] = [:]
            for (key, item) in values {
                result[key] = try decode(item, depth: depth + 1)
            }
            return .dictionary(result)
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .boolean(number.boolValue)
            }
            let type = String(cString: number.objCType)
            if ["f", "d"].contains(type) { return .real(number.doubleValue) }
            return .integer(number.int64Value)
        }
        throw PlistEditorError.unsupportedValue
    }

    fileprivate var foundationValue: Any {
        switch self {
        case .dictionary(let values): return values.mapValues(\.foundationValue)
        case .array(let values): return values.map(\.foundationValue)
        case .string(let value): return value
        case .integer(let value): return NSNumber(value: value)
        case .real(let value): return NSNumber(value: value)
        case .boolean(let value): return NSNumber(value: value)
        case .data(let value): return value
        case .date(let value): return value
        }
    }
}

public struct PlistEdit: Sendable, Equatable {
    public enum Operation: Sendable, Equatable {
        case set(PlistValue)
        case remove
    }

    public let path: [String]
    public let operation: Operation

    public init(path: [String], operation: Operation) {
        self.path = path
        self.operation = operation
    }

    public static func set(_ value: PlistValue, at path: [String]) -> PlistEdit {
        PlistEdit(path: path, operation: .set(value))
    }

    public static func remove(at path: [String]) -> PlistEdit {
        PlistEdit(path: path, operation: .remove)
    }
}

public struct PlistChange: Sendable, Equatable {
    public let path: [String]
    public let previousValue: PlistValue?
    public let proposedValue: PlistValue?
}

public struct PlistChangePlan: Sendable, Equatable {
    public let id: UUID
    public let sourceSHA256: String
    public let proposedSHA256: String
    public let changes: [PlistChange]
    public let proposedData: Data
    public let confirmationToken: String
    public let createdAt: Date

    fileprivate init(
        id: UUID,
        sourceSHA256: String,
        proposedSHA256: String,
        changes: [PlistChange],
        proposedData: Data,
        confirmationToken: String,
        createdAt: Date
    ) {
        self.id = id
        self.sourceSHA256 = sourceSHA256
        self.proposedSHA256 = proposedSHA256
        self.changes = changes
        self.proposedData = proposedData
        self.confirmationToken = confirmationToken
        self.createdAt = createdAt
    }
}

public enum PlistEditorError: Error, Equatable {
    case invalidPropertyList
    case rootMustBeDictionary
    case unsupportedValue
    case maximumDepthExceeded
    case invalidPath
    case missingKey
    case duplicatePath
    case emptyChanges
    case sourceChanged
    case invalidPlan
    case confirmationRequired
}

public struct PlistEditor: Sendable {
    public let maximumInputBytes: Int
    public let maximumChanges: Int

    public init(maximumInputBytes: Int = 16 * 1_024 * 1_024, maximumChanges: Int = 256) {
        self.maximumInputBytes = maximumInputBytes
        self.maximumChanges = maximumChanges
    }

    /// Parse XML or binary plist data. The editor intentionally requires a
    /// dictionary root because configuration edits are addressed by key path.
    public func decode(_ data: Data) throws -> PlistValue {
        guard !data.isEmpty, data.count <= maximumInputBytes else {
            throw PlistEditorError.invalidPropertyList
        }
        let object: Any
        do {
            object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw PlistEditorError.invalidPropertyList
        }
        let value = try PlistValue.decode(object)
        guard case .dictionary = value else { throw PlistEditorError.rootMustBeDictionary }
        return value
    }

    public func encode(_ value: PlistValue) throws -> Data {
        guard case .dictionary = value else { throw PlistEditorError.rootMustBeDictionary }
        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: value.foundationValue,
                format: .xml,
                options: 0
            )
            guard data.count <= maximumInputBytes else { throw PlistEditorError.invalidPropertyList }
            return data
        } catch let error as PlistEditorError {
            throw error
        } catch {
            throw PlistEditorError.invalidPropertyList
        }
    }

    /// Produce a deterministic before/after change list without writing any file.
    public func preview(_ sourceData: Data, edits: [PlistEdit]) throws -> PlistChangePlan {
        guard !edits.isEmpty else { throw PlistEditorError.emptyChanges }
        guard edits.count <= maximumChanges else { throw PlistEditorError.invalidPlan }

        let source = try decode(sourceData)
        var candidate = source
        var changes: [PlistChange] = []
        var seen = Set<[String]>()

        for edit in edits {
            guard !edit.path.isEmpty,
                  edit.path.count <= 16,
                  edit.path.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 }),
                  seen.insert(edit.path).inserted else {
                throw edit.path.isEmpty ? PlistEditorError.invalidPath : PlistEditorError.duplicatePath
            }
            let previous = try value(at: edit.path, in: candidate)
            let proposed: PlistValue?
            switch edit.operation {
            case .set(let value):
                proposed = value
            case .remove:
                guard previous != nil else { throw PlistEditorError.missingKey }
                proposed = nil
            }
            candidate = try replacing(edit.path[...], in: candidate, with: proposed)
            changes.append(PlistChange(path: edit.path, previousValue: previous, proposedValue: proposed))
        }

        let proposedData = try encode(candidate)
        let sourceDigest = Self.sha256(sourceData)
        let proposedDigest = Self.sha256(proposedData)
        let id = UUID()
        let createdAt = Date()
        let tokenMaterial = "(id.uuidString)|(sourceDigest)|(proposedDigest)|(changes.count)"
        let token = Self.sha256(Data(tokenMaterial.utf8))
        return PlistChangePlan(
            id: id,
            sourceSHA256: sourceDigest,
            proposedSHA256: proposedDigest,
            changes: changes,
            proposedData: proposedData,
            confirmationToken: token,
            createdAt: createdAt
        )
    }

    /// Revalidates the source and plan. This returns edited bytes only; it does
    /// not replace files or mutate the live iOS system configuration.
    public func applyPreview(
        _ plan: PlistChangePlan,
        to currentSource: Data,
        confirmationToken: String
    ) throws -> Data {
        guard Self.sha256(currentSource) == plan.sourceSHA256 else {
            throw PlistEditorError.sourceChanged
        }
        guard confirmationToken == plan.confirmationToken,
              !plan.changes.isEmpty,
              plan.changes.count <= maximumChanges,
              Self.sha256(plan.proposedData) == plan.proposedSHA256 else {
            throw PlistEditorError.invalidPlan
        }
        _ = try decode(plan.proposedData)
        return plan.proposedData
    }

    private func value(at path: [String], in root: PlistValue) throws -> PlistValue? {
        var current = root
        for key in path {
            guard case .dictionary(let values) = current else { throw PlistEditorError.invalidPath }
            guard let next = values[key] else { return nil }
            current = next
        }
        return current
    }

    private func replacing(
        _ path: ArraySlice<String>,
        in current: PlistValue,
        with replacement: PlistValue?
    ) throws -> PlistValue {
        guard let key = path.first, case .dictionary(var values) = current else {
            throw PlistEditorError.invalidPath
        }
        if path.count == 1 {
            if let replacement {
                values[key] = replacement
            } else {
                guard values.removeValue(forKey: key) != nil else { throw PlistEditorError.missingKey }
            }
            return .dictionary(values)
        }
        guard let child = values[key] else { throw PlistEditorError.missingKey }
        values[key] = try replacing(path.dropFirst(), in: child, with: replacement)
        return .dictionary(values)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
