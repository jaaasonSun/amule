import AMuleECBridgeAdapter

public actor RemoteSessionCoordinator {
    public enum FailurePolicy: Sendable, Equatable {
        case continuePolling
        case stopAndRecoverViaLifecycle
    }

    public static let macOSFailurePolicy = FailurePolicy.continuePolling
    public static let iOSFailurePolicy = FailurePolicy.stopAndRecoverViaLifecycle

    private enum Resource: Hashable, Sendable {
        case status
        case downloads
        case servers
    }

    private enum RefreshRequest {
        case poll
        case manual
        case mutation

        var followUpPriority: FollowUpPriority? {
            switch self {
            case .poll:
                nil
            case .manual:
                .manual
            case .mutation:
                .mutation
            }
        }
    }

    private enum FollowUpPriority: Int, Sendable {
        case manual
        case mutation

        var taskPriority: TaskPriority {
            switch self {
            case .manual:
                .medium
            case .mutation:
                .high
            }
        }
    }

    private enum ResourceGate {
        case idle
        case running
        case pending(FollowUpPriority)
    }

    private enum BeginRefreshResult {
        case start
        case skipped
        case queuedFollowUp
    }

    private let bridge: any BridgeProtocol
    private let config: AMuleConnectionConfig
    private var gates: [Resource: ResourceGate] = [
        .status: .idle,
        .downloads: .idle,
        .servers: .idle,
    ]
    private var statusFollowUpWaiters: [CheckedContinuation<(BridgeStatusPayload, String)?, Error>] = []
    private var downloadsFollowUpWaiters: [CheckedContinuation<([BridgeDownloadPayload], String)?, Error>] = []
    private var serversFollowUpWaiters: [CheckedContinuation<([BridgeServerPayload], String)?, Error>] = []
    private var bufferedStatusFollowUp: Result<(BridgeStatusPayload, String), Error>?
    private var bufferedDownloadsFollowUp: Result<([BridgeDownloadPayload], String), Error>?
    private var bufferedServersFollowUp: Result<([BridgeServerPayload], String), Error>?

    public init(bridge: any BridgeProtocol, config: AMuleConnectionConfig) {
        self.bridge = bridge
        self.config = config
    }

    public func pollStatus() async throws -> (BridgeStatusPayload, String)? {
        try await refreshStatus(request: .poll)
    }

    public func manualRefreshStatus() async throws -> (BridgeStatusPayload, String)? {
        try await refreshStatus(request: .manual)
    }

    public func mutationRefreshStatus() async throws -> (BridgeStatusPayload, String)? {
        try await refreshStatus(request: .mutation)
    }

    public func pollDownloads() async throws -> ([BridgeDownloadPayload], String)? {
        try await refreshDownloads(request: .poll)
    }

    public func manualRefreshDownloads() async throws -> ([BridgeDownloadPayload], String)? {
        try await refreshDownloads(request: .manual)
    }

    public func mutationRefreshDownloads() async throws -> ([BridgeDownloadPayload], String)? {
        try await refreshDownloads(request: .mutation)
    }

    public func pollServers() async throws -> ([BridgeServerPayload], String)? {
        try await refreshServers(request: .poll)
    }

    public func manualRefreshServers() async throws -> ([BridgeServerPayload], String)? {
        try await refreshServers(request: .manual)
    }

    public func mutationRefreshServers() async throws -> ([BridgeServerPayload], String)? {
        try await refreshServers(request: .mutation)
    }

    private func refreshStatus(
        request: RefreshRequest
    ) async throws -> (BridgeStatusPayload, String)? {
        switch beginRefresh(for: .status, request: request) {
        case .skipped:
            return nil
        case .queuedFollowUp:
            return try await waitForStatusFollowUp()
        case .start:
            break
        }

        do {
            let snapshot = try await bridge.status(config: config)
            let didScheduleFollowUp = finishRefresh(for: .status)
            return didScheduleFollowUp ? nil : snapshot
        } catch {
            finishRefresh(for: .status)
            throw error
        }
    }

    private func refreshDownloads(
        request: RefreshRequest
    ) async throws -> ([BridgeDownloadPayload], String)? {
        switch beginRefresh(for: .downloads, request: request) {
        case .skipped:
            return nil
        case .queuedFollowUp:
            return try await waitForDownloadsFollowUp()
        case .start:
            break
        }

        do {
            let snapshot = try await bridge.downloads(config: config)
            let didScheduleFollowUp = finishRefresh(for: .downloads)
            return didScheduleFollowUp ? nil : snapshot
        } catch {
            finishRefresh(for: .downloads)
            throw error
        }
    }

    private func refreshServers(
        request: RefreshRequest
    ) async throws -> ([BridgeServerPayload], String)? {
        switch beginRefresh(for: .servers, request: request) {
        case .skipped:
            return nil
        case .queuedFollowUp:
            return try await waitForServersFollowUp()
        case .start:
            break
        }

        do {
            let snapshot = try await bridge.servers(config: config)
            let didScheduleFollowUp = finishRefresh(for: .servers)
            return didScheduleFollowUp ? nil : snapshot
        } catch {
            finishRefresh(for: .servers)
            throw error
        }
    }

    private func beginRefresh(for resource: Resource, request: RefreshRequest) -> BeginRefreshResult {
        switch gates[resource, default: .idle] {
        case .idle:
            gates[resource] = .running
            return .start
        case .running:
            recordPendingRefresh(for: resource, request: request)
            return request.followUpPriority == nil ? .skipped : .queuedFollowUp
        case .pending:
            recordPendingRefresh(for: resource, request: request)
            return request.followUpPriority == nil ? .skipped : .queuedFollowUp
        }
    }

    private func recordPendingRefresh(for resource: Resource, request: RefreshRequest) {
        guard let newPriority = request.followUpPriority else { return }

        switch gates[resource, default: .idle] {
        case .running:
            gates[resource] = .pending(newPriority)
        case .pending(let existingPriority):
            let priority = existingPriority.rawValue >= newPriority.rawValue
                ? existingPriority
                : newPriority
            gates[resource] = .pending(priority)
        case .idle:
            break
        }
    }

    @discardableResult
    private func finishRefresh(for resource: Resource) -> Bool {
        switch gates[resource, default: .idle] {
        case .pending(let priority):
            gates[resource] = .running
            scheduleFollowUp(for: resource, priority: priority)
            return true
        case .running, .idle:
            gates[resource] = .idle
            return false
        }
    }

    private func scheduleFollowUp(for resource: Resource, priority: FollowUpPriority) {
        Task.detached(priority: priority.taskPriority) { [weak self] in
            await self?.performFollowUp(for: resource)
        }
    }

    private func performFollowUp(for resource: Resource) async {
        do {
            switch resource {
            case .status:
                let snapshot = try await bridge.status(config: config)
                resumeStatusFollowUpWaiters(with: .success(snapshot))
            case .downloads:
                let snapshot = try await bridge.downloads(config: config)
                resumeDownloadsFollowUpWaiters(with: .success(snapshot))
            case .servers:
                let snapshot = try await bridge.servers(config: config)
                resumeServersFollowUpWaiters(with: .success(snapshot))
            }
        } catch {
            switch resource {
            case .status:
                resumeStatusFollowUpWaiters(with: .failure(error))
            case .downloads:
                resumeDownloadsFollowUpWaiters(with: .failure(error))
            case .servers:
                resumeServersFollowUpWaiters(with: .failure(error))
            }
        }

        finishRefresh(for: resource)
    }

    private func waitForStatusFollowUp() async throws -> (BridgeStatusPayload, String)? {
        if let result = bufferedStatusFollowUp {
            bufferedStatusFollowUp = nil
            return try result.get()
        }

        return try await withCheckedThrowingContinuation { continuation in
            statusFollowUpWaiters.append(continuation)
        }
    }

    private func waitForDownloadsFollowUp() async throws -> ([BridgeDownloadPayload], String)? {
        if let result = bufferedDownloadsFollowUp {
            bufferedDownloadsFollowUp = nil
            return try result.get()
        }

        return try await withCheckedThrowingContinuation { continuation in
            downloadsFollowUpWaiters.append(continuation)
        }
    }

    private func waitForServersFollowUp() async throws -> ([BridgeServerPayload], String)? {
        if let result = bufferedServersFollowUp {
            bufferedServersFollowUp = nil
            return try result.get()
        }

        return try await withCheckedThrowingContinuation { continuation in
            serversFollowUpWaiters.append(continuation)
        }
    }

    private func resumeStatusFollowUpWaiters(with result: Result<(BridgeStatusPayload, String), Error>) {
        let waiters = statusFollowUpWaiters
        statusFollowUpWaiters.removeAll()
        guard !waiters.isEmpty else {
            bufferedStatusFollowUp = result
            return
        }
        waiters.forEach { waiter in
            switch result {
            case .success(let snapshot):
                waiter.resume(returning: snapshot)
            case .failure(let error):
                waiter.resume(throwing: error)
            }
        }
    }

    private func resumeDownloadsFollowUpWaiters(with result: Result<([BridgeDownloadPayload], String), Error>) {
        let waiters = downloadsFollowUpWaiters
        downloadsFollowUpWaiters.removeAll()
        guard !waiters.isEmpty else {
            bufferedDownloadsFollowUp = result
            return
        }
        waiters.forEach { waiter in
            switch result {
            case .success(let snapshot):
                waiter.resume(returning: snapshot)
            case .failure(let error):
                waiter.resume(throwing: error)
            }
        }
    }

    private func resumeServersFollowUpWaiters(with result: Result<([BridgeServerPayload], String), Error>) {
        let waiters = serversFollowUpWaiters
        serversFollowUpWaiters.removeAll()
        guard !waiters.isEmpty else {
            bufferedServersFollowUp = result
            return
        }
        waiters.forEach { waiter in
            switch result {
            case .success(let snapshot):
                waiter.resume(returning: snapshot)
            case .failure(let error):
                waiter.resume(throwing: error)
            }
        }
    }
}
