import Foundation
import AMuleECProtocol
import Synchronization

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
        try Task.checkCancellation()
        guard seconds > 0 else { return try await body() }

        let race = ECTimeoutRace<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                race.start(
                    continuation: continuation,
                    seconds: seconds,
                    operation: operation,
                    body: body
                )
            }
        } onCancel: {
            race.cancel()
        }
    }
}

@available(macOS 10.14, iOS 12.0, *)
private final class ECTimeoutRace<T: Sendable>: Sendable {
    private struct State: Sendable {
        var continuation: CheckedContinuation<T, Error>?
        var operationTask: Task<Void, Never>?
        var timeoutTask: Task<Void, Never>?
        var terminalResult: Result<T, Error>?
    }

    private let state = Mutex(State())

    func start(
        continuation: CheckedContinuation<T, Error>,
        seconds: TimeInterval,
        operation: ECSessionError.ECOperation,
        body: @escaping @Sendable () async throws -> T
    ) {
        let terminalResult = state.withLock { state -> Result<T, Error>? in
            if let terminalResult = state.terminalResult {
                return terminalResult
            }
            state.continuation = continuation
            return nil
        }
        if let terminalResult {
            continuation.resume(with: terminalResult)
            return
        }

        if Task.isCancelled {
            cancel()
            return
        }

        let operationTask = Task {
            do {
                finish(.success(try await body()))
            } catch {
                finish(.failure(error))
            }
        }
        install(operationTask: operationTask)

        let timeoutTask = Task {
            do {
                try await Task.sleep(for: .seconds(seconds))
                finish(.failure(ECSessionError.timeout(operation)))
            } catch is CancellationError {
                return
            } catch {
                finish(.failure(error))
            }
        }
        install(timeoutTask: timeoutTask)
    }

    func cancel() {
        finish(.failure(CancellationError()))
    }

    private func install(operationTask: Task<Void, Never>) {
        let shouldCancel = state.withLock { state in
            guard state.terminalResult == nil else { return true }
            state.operationTask = operationTask
            return false
        }
        if shouldCancel {
            operationTask.cancel()
        }
    }

    private func install(timeoutTask: Task<Void, Never>) {
        let shouldCancel = state.withLock { state in
            guard state.terminalResult == nil else { return true }
            state.timeoutTask = timeoutTask
            return false
        }
        if shouldCancel {
            timeoutTask.cancel()
        }
    }

    private func finish(_ result: Result<T, Error>) {
        let completion = state.withLock { state -> (
            CheckedContinuation<T, Error>?,
            Task<Void, Never>?,
            Task<Void, Never>?
        )? in
            guard state.terminalResult == nil else { return nil }
            state.terminalResult = result
            let completion = (state.continuation, state.operationTask, state.timeoutTask)
            state.continuation = nil
            state.operationTask = nil
            state.timeoutTask = nil
            return completion
        }
        guard let (continuation, operationTask, timeoutTask) = completion else { return }

        operationTask?.cancel()
        timeoutTask?.cancel()
        continuation?.resume(with: result)
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
