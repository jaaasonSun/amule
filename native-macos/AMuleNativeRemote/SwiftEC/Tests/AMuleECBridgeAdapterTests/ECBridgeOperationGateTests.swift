import XCTest
import Foundation
import AMuleECClient
import AMuleECProtocol
@testable import AMuleECBridgeAdapter

private actor SuspendedGateOperation {
    private var continuation: CheckedContinuation<Void, Never>?
    private var started = false
    private(set) var cancelledOperationRan = false

    func suspend() async {
        started = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilStarted() async -> Bool {
        for _ in 0..<1_000 {
            if started { return true }
            await Task.yield()
        }
        return started
    }

    func markCancelledOperationRan() {
        cancelledOperationRan = true
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

@available(macOS 10.15, iOS 13.0, *)
private actor SuspendedStatusTransport: ECConnectionTransport {
    private var replies: [ECPacket]
    private var suspendedReceive: CheckedContinuation<ECPacket, Never>?

    init(replies: [ECPacket]) {
        self.replies = replies
    }

    func connect(timeout: TimeInterval) async throws {}

    func disconnect() async {}

    func send(_ packet: ECPacket, timeout: TimeInterval, compressionEnabled: Bool) async throws {}

    func receivePacket(timeout: TimeInterval, partialReadTimeout: TimeInterval) async throws -> ECPacket {
        if !replies.isEmpty {
            return replies.removeFirst()
        }
        return await withCheckedContinuation { continuation in
            suspendedReceive = continuation
        }
    }

    func waitUntilReceiveSuspends() async -> Bool {
        for _ in 0..<1_000 {
            if suspendedReceive != nil { return true }
            await Task.yield()
        }
        return suspendedReceive != nil
    }

    func resumeSuspendedReceive() {
        suspendedReceive?.resume(returning: ECPacket(opcode: 0x04))
        suspendedReceive = nil
    }
}

final class ECBridgeOperationGateTests: XCTestCase {
    func testCancellingQueuedOperationDoesNotBlockLaterOperations() async throws {
        let gate = ECBridgeOperationGate()
        let probe = SuspendedGateOperation()
        let first = Task {
            try await gate.run {
                await probe.suspend()
            }
        }

        guard await probe.waitUntilStarted() else {
            first.cancel()
            XCTFail("The gate holder did not start")
            return
        }

        let cancelled = Task {
            try await gate.run {
                await probe.markCancelledOperationRan()
            }
        }
        for _ in 0..<1_000 {
            if await gate.queuedOperationCount == 1 { break }
            await Task.yield()
        }
        let queuedOperationCount = await gate.queuedOperationCount
        XCTAssertEqual(queuedOperationCount, 1)

        cancelled.cancel()
        do {
            try await cancelled.value
            XCTFail("Expected queued operation cancellation")
        } catch is CancellationError {
        }

        await probe.resume()
        try await first.value
        let cancelledOperationRan = await probe.cancelledOperationRan
        XCTAssertFalse(cancelledOperationRan)

        let finalValue = try await gate.run { 42 }
        XCTAssertEqual(finalValue, 42)
    }

    @available(macOS 10.15, iOS 13.0, *)
    func testTimedOutReceiveReleasesGateForLaterDisconnect() async throws {
        let salt = ECPacket(
            flags: ECAuthPacket.baseFlags,
            opcode: ECAuthPacket.opAuthSalt,
            tags: [ECTag.integer(name: ECAuthPacket.tagPasswordSalt, value: 0x1234_abcd)]
        )
        let authentication = ECPacket(
            flags: ECAuthPacket.baseFlags,
            opcode: ECAuthPacket.opAuthOK
        )
        let transport = SuspendedStatusTransport(replies: [salt, authentication])
        let session = ECSession(
            configuration: .init(
                host: "127.0.0.1",
                port: 4712,
                password: "secret",
                requestTimeout: 0.01,
                automaticReconnect: false
            ),
            transportFactory: { transport }
        )
        let adapter = SwiftECBridgeAdapter(session: session)
        let config = AMuleConnectionConfig(password: "secret")
        let completed = expectation(description: "status timeout returned")
        let status = Task<Result<BridgeStatusPayload, Error>, Never> {
            do {
                let result = try await adapter.status(config: config).0
                completed.fulfill()
                return .success(result)
            } catch {
                completed.fulfill()
                return .failure(error)
            }
        }

        guard await transport.waitUntilReceiveSuspends() else {
            status.cancel()
            XCTFail("The controlled status receive did not suspend")
            return
        }
        await fulfillment(of: [completed], timeout: 0.5)

        switch await status.value {
        case .success:
            XCTFail("Expected the status request to time out")
        case .failure(let error):
            XCTAssertEqual(error as? ECSessionError, .timeout(.request))
        }

        _ = try await adapter.disconnect(config: config)
        await transport.resumeSuspendedReceive()
    }
}
