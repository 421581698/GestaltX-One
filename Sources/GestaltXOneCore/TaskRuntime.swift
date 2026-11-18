import Foundation

public enum TaskState: String, Codable, Sendable {
    case queued
    case checking
    case awaitingAuthorization = "awaiting_authorization"
    case running
    case verifying
    case completed
    case failed
    case cancelled
    case rolledBack = "rolled_back"

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .rolledBack: true
        default: false
        }
    }
}

public struct TaskEvent: Codable, Sendable, Equatable {
    public let taskID: UUID
    public let state: TaskState
    public let message: String
    public let timestamp: Date

    public init(taskID: UUID, state: TaskState, message: String, timestamp: Date = .now) {
        self.taskID = taskID
        self.state = state
        self.message = message
        self.timestamp = timestamp
    }
}

public struct TaskSnapshot: Codable, Sendable {
    public let id: UUID
    public let state: TaskState
    public let events: [TaskEvent]
}

public actor TaskRuntime {
    private struct Record {
        var state: TaskState
        var events: [TaskEvent]
    }

    private var records: [UUID: Record] = [:]

    public init() {}

    @discardableResult
    public func createTask(message: String = "Task queued") -> UUID {
        let id = UUID()
        let event = TaskEvent(taskID: id, state: .queued, message: message)
        records[id] = Record(state: .queued, events: [event])
        return id
    }

    public func transition(_ id: UUID, to next: TaskState, message: String) throws {
        guard var record = records[id] else { throw TaskRuntimeError.taskNotFound }
        guard !record.state.isTerminal else { throw TaskRuntimeError.terminalTask }
        guard Self.allowedTransitions[record.state, default: []].contains(next) else {
            throw TaskRuntimeError.invalidTransition(from: record.state, to: next)
        }
        record.state = next
        record.events.append(TaskEvent(taskID: id, state: next, message: message))
        records[id] = record
    }

    public func snapshot(_ id: UUID) -> TaskSnapshot? {
        guard let record = records[id] else { return nil }
        return TaskSnapshot(id: id, state: record.state, events: record.events)
    }

    private static let allowedTransitions: [TaskState: Set<TaskState>] = [
        .queued: [.checking, .cancelled, .failed],
        .checking: [.awaitingAuthorization, .running, .failed, .cancelled],
        .awaitingAuthorization: [.running, .cancelled, .failed],
        .running: [.verifying, .failed, .cancelled, .rolledBack],
        .verifying: [.completed, .failed, .rolledBack],
        .rolledBack: []
    ]
}

public enum TaskRuntimeError: Error, Equatable {
    case taskNotFound
    case terminalTask
    case invalidTransition(from: TaskState, to: TaskState)
}
