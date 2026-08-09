import XCTest
@testable import AMuleECClient

@available(macOS 10.14, iOS 12.0, *)
private actor SuspendedTimeoutOperation {
    private var continuation: CheckedContinuation<Int, Never>?
    private var started = false

    func wait() async -> Int {
        started = true
        return await withCheckedContinuation { continuation in
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

    func resume() {
        continuation?.resume(returning: 42)
        continuation = nil
    }
}

@available(macOS 10.14, iOS 12.0, *)
final class ECTimeoutTests: XCTestCase {
    func testBodyCanCompleteBeforeTimeout() async throws {
        let value = try await ECTimeout.run(seconds: 1, operation: .request) {
            42
        }

        XCTAssertEqual(value, 42)
    }

    func testParentCancellationReturnsWithoutWaitingForSuspendedBody() async throws {
        let operation = SuspendedTimeoutOperation()
        let completed = expectation(description: "cancellation returned")
        let result = Task<Result<Int, Error>, Never> {
            do {
                let value = try await ECTimeout.run(seconds: 1, operation: .request) {
                    await operation.wait()
                }
                completed.fulfill()
                return .success(value)
            } catch {
                completed.fulfill()
                return .failure(error)
            }
        }

        guard await operation.waitUntilStarted() else {
            result.cancel()
            XCTFail("The controlled operation did not start")
            return
        }
        result.cancel()

        await fulfillment(of: [completed], timeout: 0.5)
        await operation.resume()

        switch await result.value {
        case .success(let value):
            XCTFail("Expected cancellation, got value \(value)")
        case .failure(let error):
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testTimeoutReturnsWithoutWaitingForBodyThatIgnoresCancellation() async throws {
        let operation = SuspendedTimeoutOperation()
        let completed = expectation(description: "timeout returned")
        let result = Task<Result<Int, Error>, Never> {
            do {
                let value = try await ECTimeout.run(seconds: 0.01, operation: .request) {
                    await operation.wait()
                }
                completed.fulfill()
                return .success(value)
            } catch {
                completed.fulfill()
                return .failure(error)
            }
        }

        guard await operation.waitUntilStarted() else {
            result.cancel()
            XCTFail("The controlled operation did not start")
            return
        }

        await fulfillment(of: [completed], timeout: 0.5)
        await operation.resume()

        switch await result.value {
        case .success(let value):
            XCTFail("Expected timeout, got value \(value)")
        case .failure(let error):
            XCTAssertEqual(error as? ECSessionError, .timeout(.request))
        }
    }
}
