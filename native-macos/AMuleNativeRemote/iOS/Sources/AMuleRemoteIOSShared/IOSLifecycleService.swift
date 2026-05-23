import Foundation
import Network
import SwiftUI

public enum AppLifecycleEffect: Equatable {
    case none
    case pauseAutoRefresh
    case resumeAutoRefresh(shouldReconnect: Bool)
}

public enum NetworkReachabilityStatus: Equatable {
    case satisfied
    case requiresConnection
    case unsatisfied

    public init(_ status: NWPath.Status) {
        switch status {
        case .satisfied:
            self = .satisfied
        case .requiresConnection:
            self = .requiresConnection
        default:
            self = .unsatisfied
        }
    }

    public var isReachable: Bool {
        self == .satisfied
    }
}

public protocol NetworkPathMonitoring: AnyObject {
    var currentStatus: NetworkReachabilityStatus { get }
    var statusUpdateHandler: (@Sendable (NetworkReachabilityStatus) -> Void)? { get set }
    func start(queue: DispatchQueue)
    func cancel()
}

public final class NWPathMonitorAdapter: NetworkPathMonitoring {
    private let monitor = NWPathMonitor()

    public init() {}

    public var currentStatus: NetworkReachabilityStatus {
        NetworkReachabilityStatus(monitor.currentPath.status)
    }

    public var statusUpdateHandler: (@Sendable (NetworkReachabilityStatus) -> Void)? {
        didSet {
            monitor.pathUpdateHandler = { [statusUpdateHandler] path in
                statusUpdateHandler?(NetworkReachabilityStatus(path.status))
            }
        }
    }

    public func start(queue: DispatchQueue) {
        monitor.start(queue: queue)
    }

    public func cancel() {
        monitor.cancel()
    }
}

@MainActor
public final class IOSLifecycleService: AppLifecycleProtocol {
    private let lifecycleBackground: LifecycleBackground
    private let monitorFactory: @Sendable () -> NetworkPathMonitoring
    private let monitorQueue = DispatchQueue(label: "org.amule.remote.ios.lifecycle.network")

    private var monitor: NetworkPathMonitoring?
    private var reconnectBackgroundToken: Any?
    private var shouldReconnectOnForeground = false

    public private(set) var isNetworkReachable = true

    public init(
        lifecycleBackground: LifecycleBackground = platformDefaultLifecycleBackground(),
        monitorFactory: @escaping @Sendable () -> NetworkPathMonitoring = { NWPathMonitorAdapter() }
    ) {
        self.lifecycleBackground = lifecycleBackground
        self.monitorFactory = monitorFactory
    }

    public func start() {
        guard monitor == nil else { return }

        let monitor = monitorFactory()
        isNetworkReachable = monitor.currentStatus.isReachable
        monitor.statusUpdateHandler = { [weak self] status in
            let isReachable = status.isReachable
            Task { @MainActor [weak self] in
                self?.isNetworkReachable = isReachable
            }
        }
        monitor.start(queue: monitorQueue)
        self.monitor = monitor
    }

    public func stop() {
        monitor?.cancel()
        monitor = nil
        lifecycleBackground.endBackgroundActivity(reconnectBackgroundToken)
        reconnectBackgroundToken = nil
        shouldReconnectOnForeground = false
    }

    public func handleScenePhaseChange(_ phase: ScenePhase, isSessionConnected: Bool) -> AppLifecycleEffect {
        switch phase {
        case .background:
            shouldReconnectOnForeground = isSessionConnected
            reconnectBackgroundToken = lifecycleBackground.beginBackgroundActivity(reason: "aMule Remote foreground reconnect")
            return .pauseAutoRefresh
        case .active:
            lifecycleBackground.endBackgroundActivity(reconnectBackgroundToken)
            reconnectBackgroundToken = nil
            let shouldReconnect = shouldReconnectOnForeground || !isSessionConnected
            shouldReconnectOnForeground = false
            return .resumeAutoRefresh(shouldReconnect: shouldReconnect)
        default:
            return .none
        }
    }
}
