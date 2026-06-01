import Foundation
import AMuleECClient
import AMuleECProtocol

/// Bridge adapter conforming to BridgeProtocol using native Swift EC implementation.
@available(macOS 10.15, iOS 13.0, *)
public struct SwiftECBridgeAdapter: BridgeProtocol, Sendable {
    private let session: ECSession?
    private let makeSession: @Sendable (AMuleConnectionConfig) -> ECSession
    private let capabilitiesPayload: ECCapabilities
    private let capabilityGate: ECCapabilityGate
    private let modelState = ECBridgeModelState()

    public init(session: ECSession? = nil, capabilities: ECCapabilities = ECOperations.capabilities()) {
        self.session = session
        self.capabilitiesPayload = capabilities
        self.capabilityGate = ECCapabilityGate(capabilities: capabilities)
        self.makeSession = { config in
            ECSession(configuration: config.ecSessionConfiguration)
        }
    }

    init(sessionFactory: @escaping @Sendable (AMuleConnectionConfig) -> ECSession, capabilities: ECCapabilities = ECOperations.capabilities()) {
        self.session = nil
        self.capabilitiesPayload = capabilities
        self.capabilityGate = ECCapabilityGate(capabilities: capabilities)
        self.makeSession = sessionFactory
    }

    public func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAuthenticatedSession(for: config) { _ in }
        return try messageResponse("Connected")
    }

    public func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        await session(for: config).disconnect()
        return try messageResponse("Disconnected")
    }

    public func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        let capabilities = capabilitiesPayload
        let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.capabilities(capabilities))
        return (1, capabilities, raw)
    }

    public func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        try await withAuthenticatedSession(for: config) { session in
            let packet = try await session.send(try ECOperations.status(gate: capabilityGate))
            let status = try ECResponseParser.parseStatus(packet)
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.status(status))
            return (status, raw)
        }
    }

    public func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        try await withAuthenticatedSession(for: config) { session in
            let packet = try await session.send(try ECOperations.downloadsUpdate(gate: capabilityGate))
            let downloads = try ECResponseParser.parseDownloads(packet)
            let result = await modelState.replaceDownloads(downloads, sourcePacket: packet)
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.downloads(result))
            return (result, raw)
        }
    }

    public func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        try await withAuthenticatedSession(for: config) { session in
            let startResponse = try await session.send(try ECOperations.search(scope: scope, query: query, gate: capabilityGate))
            _ = try ECResponseParser.parseMutationResponse(
                startResponse,
                successMessage: "Search started",
                expectedSuccessOpcodes: [ECOperations.OpCode.strings]
            )
            var progress = 0
            var ordered: [ECSearchResult] = []
            var indexByID: [Int: Int] = [:]

            for _ in 0..<max(1, polls) {
                try await Task.sleep(nanoseconds: UInt64(max(0, pollIntervalMs)) * 1_000_000)
                progress = try ECResponseParser.parseSearchProgress(try await session.send(ECOperations.searchProgress()))
                for result in try ECResponseParser.parseSearchResults(try await session.send(ECOperations.searchResults())) {
                    if let index = indexByID[result.id] {
                        ordered[index] = result
                    } else {
                        indexByID[result.id] = ordered.count
                        ordered.append(result)
                    }
                }
                if progress >= 100, !ordered.isEmpty { break }
            }

            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.search(progress: progress, results: ordered))
            return (progress, ordered, raw)
        }
    }

    public func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(
            try ECOperations.searchStop(gate: capabilityGate),
            message: "Search stop requested",
            expectedSuccessOpcodes: [ECOperations.OpCode.miscData],
            config: config
        )
    }

    public func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(
            try ECOperations.download(hash: hash, gate: capabilityGate),
            message: "Download request accepted",
            expectedSuccessOpcodes: [ECOperations.OpCode.strings],
            config: config
        )
    }

    public func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.addLink(link, gate: capabilityGate), message: "Link add request accepted", config: config)
    }

    public func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement {
        do {
            let response = try await mutation(try ECOperations.rename(hash: hash, name: name, gate: capabilityGate), message: "Rename requested", config: config)
            return .success(message: response.message, raw: response.raw)
        } catch let error as ECResponseParserError {
            return try .failure(error.localizedDescription)
        } catch ECSessionError.connectionClosed {
            // Some cores close the EC socket after a rename request instead of returning
            // EC_OP_NOOP. Treat that as an indeterminate send and let the caller refresh
            // the download list to verify whether the daemon applied the change.
            return try .ok("Rename requested", kind: .disconnectedAfterSend)
        } catch ECSessionError.timeout {
            return try .ok("Rename requested", kind: .timeout)
        }
    }

    public func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.pause(hash: hash, gate: capabilityGate), message: "Action completed", config: config)
    }

    public func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.resume(hash: hash, gate: capabilityGate), message: "Action completed", config: config)
    }

    public func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.serverConnect(ip: ip, port: port, gate: capabilityGate), message: "Server connect requested", config: config)
    }

    public func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.serverDisconnect(gate: capabilityGate), message: "Server disconnect requested", config: config)
    }

    public func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.serverAdd(address: address, name: name, gate: capabilityGate), message: "Server add requested", config: config)
    }

    public func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.serverRemove(ip: ip, port: port, gate: capabilityGate), message: "Server remove requested", config: config)
    }

    public func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        try await withAuthenticatedSession(for: config) { session in
            let prefs = try ECResponseParser.parseConnectionPrefs(try await session.send(try ECOperations.prefsConnectionGet(gate: capabilityGate)))
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.prefsConnection(prefs))
            return (prefs, raw)
        }
    }

    public func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.prefsConnectionSet(maxDownload: maxDownload, maxUpload: maxUpload, gate: capabilityGate), message: "Connection speed limits updated", config: config)
    }

    public func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.cancel(hash: hash, gate: capabilityGate), message: "Cancel requested", config: config)
    }

    public func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        try await withAuthenticatedSession(for: config) { session in
            let packet = try await session.send(try ECOperations.servers(gate: capabilityGate))
            let servers = try ECResponseParser.parseServers(packet)
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.servers(servers))
            return (servers, raw)
        }
    }

    public func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([BridgeDownloadSourcePayload], String) {
        try await withAuthenticatedSession(for: config) { session in
            let queuePacket = try await session.send(try ECOperations.sourcesQueueLookup(gate: capabilityGate))
            let fileID = try ECResponseParser.parseDownloadFileID(hash: hash, in: queuePacket)
            let snapshot = try ECResponseParser.parseDownloads(queuePacket)
            _ = await modelState.replaceDownloads(snapshot, sourcePacket: queuePacket)

            let sources: [ECSource]
            do {
                let packet = try await session.send(try ECOperations.sourcesUpdate(gate: capabilityGate))
                try ECResponseParser.validateSharedFilesUpdate(packet)
                sources = await modelState.applySourceUpdate(packet, requestFileID: fileID)
            } catch {
                sources = await modelState.sources(for: fileID)
            }
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.sources(sources))
            return (sources, raw)
        }
    }

    public func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.serverUpdateFromURL(url: url, gate: capabilityGate), message: "Server list update requested", config: config)
    }

    public func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.kadStart(gate: capabilityGate), message: "Kad start requested", config: config)
    }

    public func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.kadStop(gate: capabilityGate), message: "Kad stop requested", config: config)
    }

    public func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.kadBootstrap(ip: ip, port: port, gate: capabilityGate), message: "Kad bootstrap requested", config: config)
    }

    public func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.kadUpdateFromURL(url: url, gate: capabilityGate), message: "Kad nodes update requested", config: config)
    }

    public func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) {
        try await withAuthenticatedSession(for: config) { session in
            let uploads = try ECResponseParser.parseUploads(try await session.send(try ECOperations.uploads(gate: capabilityGate)))
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.uploads(uploads))
            return (uploads, raw)
        }
    }

    public func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) {
        try await withAuthenticatedSession(for: config) { session in
            let sharedFiles = try ECResponseParser.parseSharedFiles(try await session.send(try ECOperations.sharedFiles(gate: capabilityGate)))
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.sharedFiles(sharedFiles))
            return (sharedFiles, raw)
        }
    }

    public func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.sharedFilesReload(gate: capabilityGate), message: "Shared files reload requested", config: config)
    }

    public func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        try await withAuthenticatedSession(for: config) { session in
            let log = try ECResponseParser.parseCoreLog(try await session.send(try ECOperations.log(gate: capabilityGate)), kind: "log")
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.log(log))
            return (log, raw)
        }
    }

    public func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        try await withAuthenticatedSession(for: config) { session in
            let log = try ECResponseParser.parseCoreLog(try await session.send(try ECOperations.log(debug: true, gate: capabilityGate)), kind: "debug")
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.log(log))
            return (log, raw)
        }
    }

    public func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) {
        try await withAuthenticatedSession(for: config) { session in
            let categories = try ECResponseParser.parseCategories(try await session.send(try ECOperations.categories(gate: capabilityGate)))
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.categories(categories))
            return (categories, raw)
        }
    }

    public func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(
            try ECOperations.categoryCreate(name: name, path: path, comment: comment, color: color, priority: priority, gate: capabilityGate),
            message: "Category create requested",
            config: config
        )
    }

    public func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.categoryDelete(categoryID: categoryID, gate: capabilityGate), message: "Category delete requested", config: config)
    }

    public func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.ipfilterReload(gate: capabilityGate), message: "IP filter reload requested", config: config)
    }

    public func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.ipfilterUpdate(url: url, gate: capabilityGate), message: "IP filter update requested", config: config)
    }

    public func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) {
        try await withAuthenticatedSession(for: config) { session in
            let friends = try ECResponseParser.parseFriends(try await session.send(try ECOperations.friends(gate: capabilityGate)))
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.friends(friends))
            return (friends, raw)
        }
    }

    public func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.friendRemove(friendID: friendID, gate: capabilityGate), message: "Friend remove requested", config: config)
    }

    public func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.friendSlot(friendID: friendID, enabled: enabled, gate: capabilityGate), message: "Friend slot update requested", config: config)
    }

    public func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let result = try await mutation(try ECOperations.clearCompleted(ecids: ecids, gate: capabilityGate), message: "Completed downloads cleared", config: config)
        await modelState.acknowledgeClearCompleted(ecids: ecids)
        return result
    }

    public func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await mutation(try ECOperations.priority(hash: hash, value: Int(value) ?? 0, gate: capabilityGate), message: "Priority changed", config: config)
    }

    public func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) {
        try await withAuthenticatedSession(for: config) { session in
            let tree = try ECResponseParser.parseStatsTree(try await session.send(try ECOperations.statsTree(capping: capping, gate: capabilityGate)))
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.statsTree(tree))
            return (tree, raw)
        }
    }

    public func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) {
        try await withAuthenticatedSession(for: config) { session in
            let graphs = try ECResponseParser.parseStatsGraphs(try await session.send(try ECOperations.statsGraphs(width: width, scale: scale, last: last, gate: capabilityGate)))
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.statsGraphs(graphs))
            return (graphs, raw)
        }
    }

    private func session(for config: AMuleConnectionConfig) -> ECSession {
        if let session { return session }
        return makeSession(config)
    }

    private func withAuthenticatedSession<T>(
        for config: AMuleConnectionConfig,
        _ operation: (ECSession) async throws -> T
    ) async throws -> T {
        let session = session(for: config)
        let shouldDisconnect = self.session == nil
        do {
            try await session.ensureAuthenticated()
            let result = try await operation(session)
            if shouldDisconnect {
                await session.disconnect()
            }
            return result
        } catch {
            if shouldDisconnect {
                await session.disconnect()
            }
            throw error
        }
    }

    private func messageResponse(_ message: String) throws -> (message: String, raw: String) {
        let raw = ECJSONEnvelope.jsonString(try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, message: message)))
        return (message, raw)
    }

    private func mutation(
        _ packet: ECPacket,
        message: String,
        expectedSuccessOpcodes: Set<UInt8> = [ECOperations.OpCode.noop],
        config: AMuleConnectionConfig
    ) async throws -> (message: String, raw: String) {
        try await withAuthenticatedSession(for: config) { session in
            let response = try await session.send(packet)
            let message = try ECResponseParser.parseMutationResponse(response, successMessage: message, expectedSuccessOpcodes: expectedSuccessOpcodes)
            let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.message(message))
            return (message, raw)
        }
    }

    private func encode(_ envelope: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }
}

@available(macOS 10.15, iOS 13.0, *)
private actor ECBridgeModelState {
    private var downloadStore = ECDownloadStateStore()
    private var sourceStore = ECSourceStateStore()

    var downloads: [ECDownload] {
        downloadStore.downloads
    }

    func replaceDownloads(_ downloads: [ECDownload], sourcePacket: ECPacket) -> [ECDownload] {
        downloadStore.replaceDownloadSnapshot(downloads, sourcePacket: sourcePacket)
        return downloadStore.downloads
    }

    func applyIncrementalDownloadUpdate(_ packet: ECPacket) -> [ECDownload] {
        downloadStore.applyIncrementalUpdate(packet)
        return downloadStore.downloads
    }

    func acknowledgeClearCompleted(ecids: [Int]) {
        downloadStore.acknowledgeClearCompleted(ecids: ecids)
    }

    func applySourceUpdate(_ packet: ECPacket, requestFileID: Int) -> [ECSource] {
        sourceStore.applyIncrementalUpdate(packet)
        return sourceStore.sources(for: requestFileID)
    }

    func sources(for requestFileID: Int) -> [ECSource] {
        sourceStore.sources(for: requestFileID)
    }
}

public protocol BridgeProtocol: Sendable {
    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)
    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String)
    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String)
    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String)
    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement
    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String)
    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String)
    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([BridgeDownloadSourcePayload], String)
    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String)
    func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String)
    func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String)
    func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String)
    func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String)
    func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String)
    func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String)
    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String)
}

public struct AMuleConnectionConfig: Sendable {
    public var host: String
    public var port: Int
    public var password: String

    public init(host: String = "127.0.0.1", port: Int = 4712, password: String) {
        self.host = host
        self.port = port
        self.password = password
    }

    fileprivate var ecSessionConfiguration: ECSession.Configuration {
        ECSession.Configuration(host: host, port: UInt16(clamping: port), password: password)
    }
}

public typealias BridgeCapabilitiesPayload = ECCapabilities
public typealias BridgeStatusPayload = ECStatus
public typealias BridgeDownloadPayload = ECDownload
public typealias BridgeDownloadSourcePayload = ECSource
public typealias BridgeServerPayload = ECServer
public typealias BridgeUploadPayload = ECUpload
public typealias BridgeSharedFilePayload = ECSharedFile
public typealias BridgeCoreLogPayload = ECCoreLog
public typealias BridgeCategoryPayload = ECCategory
public typealias BridgeFriendPayload = ECFriend
public typealias BridgeStatsTreeNodePayload = ECStatsTreeNode
public typealias BridgeStatsGraphsPayload = ECStatsGraphs

public typealias BridgeSearchPayload = ECSearchResult
public typealias BridgeConnectionPrefsPayload = ECConnectionPrefs

public enum ECError: Error, Equatable, LocalizedError, Sendable {
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented(let operation):
            return "Operation not implemented: \(operation)"
        }
    }
}
