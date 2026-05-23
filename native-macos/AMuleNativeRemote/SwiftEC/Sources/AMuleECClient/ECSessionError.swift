import Foundation
import AMuleECProtocol

@available(macOS 10.14, iOS 12.0, *)
public enum ECSessionError: Error, Equatable, CustomStringConvertible, LocalizedError {
    case invalidPort(UInt16)
    case invalidState(expected: ECSession.State, actual: ECSession.State)
    case connectionFailed(String)
    case connectionClosed
    case timeout(ECOperation)
    case packetTooLarge(Int)
    case protocolError(String)
    case authenticationFailed(String?)

    public enum ECOperation: String, Sendable {
        case connect
        case read
        case write
        case request
        case reconnect
    }

    public var description: String {
        switch self {
        case .invalidPort(let port):
            return "Invalid EC port: \(port)."
        case .invalidState(let expected, let actual):
            return "Invalid EC session state: expected \(expected), got \(actual)."
        case .connectionFailed(let message):
            return "EC connection failed: \(message)."
        case .connectionClosed:
            return "EC connection closed."
        case .timeout(let operation):
            return "EC \(operation.rawValue) timed out."
        case .packetTooLarge(let length):
            return "EC packet too large: \(length) bytes."
        case .protocolError(let message):
            return "EC protocol error: \(message)."
        case .authenticationFailed(let reason):
            return reason.map { "EC authentication failed: \($0)." } ?? "EC authentication failed."
        }
    }

    public var errorDescription: String? {
        description
    }
}

@available(macOS 10.14, iOS 12.0, *)
enum ECTimeout {
    static func run<T: Sendable>(
        seconds: TimeInterval,
        operation: ECSessionError.ECOperation,
        _ body: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        guard seconds > 0 else { return try await body() }

        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await body() }
            group.addTask {
                let nanoseconds = UInt64(seconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                throw ECSessionError.timeout(operation)
            }

            let value = try await group.next()!
            group.cancelAll()
            return value
        }
    }
}

@available(macOS 10.14, iOS 12.0, *)
final class ECContinuationBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(throwing: error)
    }
}
