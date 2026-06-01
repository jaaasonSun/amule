import SwiftUI
import XCTest
@testable import AMuleRemoteiOS

final class IOSLifecycleServiceTests: XCTestCase {
    @MainActor
    func testBackgroundAndForegroundTransitionsPauseAndResumeReconnect() {
        let lifecycleBackground = PlatformServiceStubs.Lifecycle()
        let monitor = TestNetworkPathMonitor(status: .satisfied)
        let service = IOSLifecycleService(lifecycleBackground: lifecycleBackground) { monitor }

        service.start()

        XCTAssertEqual(service.handleScenePhaseChange(.background, isSessionConnected: true), .pauseAutoRefresh)
        XCTAssertEqual(service.handleScenePhaseChange(.active, isSessionConnected: true), .resumeAutoRefresh(shouldReconnect: true))
    }

    @MainActor
    func testForegroundResumeRequestsReconnectEvenWhenSessionWasNotConnected() {
        let service = IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle()) {
            TestNetworkPathMonitor(status: .satisfied)
        }

        XCTAssertEqual(service.handleScenePhaseChange(.background, isSessionConnected: false), .pauseAutoRefresh)
        XCTAssertEqual(service.handleScenePhaseChange(.active, isSessionConnected: false), .resumeAutoRefresh(shouldReconnect: true))
    }

    @MainActor
    func testPathMonitorUpdatesReachability() async {
        let monitor = TestNetworkPathMonitor(status: .satisfied)
        let service = IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle()) { monitor }

        service.start()
        XCTAssertTrue(service.isNetworkReachable)

        monitor.push(.unsatisfied)
        await Task.yield()

        XCTAssertFalse(service.isNetworkReachable)
    }
}

private final class TestNetworkPathMonitor: NetworkPathMonitoring, @unchecked Sendable {
    var currentStatus: NetworkReachabilityStatus
    var statusUpdateHandler: (@Sendable (NetworkReachabilityStatus) -> Void)?

    init(status: NetworkReachabilityStatus) {
        self.currentStatus = status
    }

    func start(queue: DispatchQueue) {
        _ = queue
    }

    func cancel() {}

    func push(_ status: NetworkReachabilityStatus) {
        currentStatus = status
        statusUpdateHandler?(status)
    }
}
