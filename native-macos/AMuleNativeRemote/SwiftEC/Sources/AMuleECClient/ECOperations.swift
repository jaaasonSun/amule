import Foundation
import AMuleECProtocol

public enum ECOperationError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedOperation(String)
    case invalidHash(String)
    case invalidServerEndpoint(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedOperation(let operation): return "Unsupported operation: \(operation)"
        case .invalidHash(let hash): return "Invalid hash: \(hash)"
        case .invalidServerEndpoint(let endpoint): return "Invalid server endpoint: \(endpoint)"
        }
    }
}

public struct ECCapabilityGate: Equatable, Sendable {
    public let supportedOps: Set<String>

    public init(_ supportedOps: some Sequence<String>) {
        self.supportedOps = Set(supportedOps)
    }

    public init(capabilities: ECCapabilities) {
        self.supportedOps = Set(capabilities.ops)
    }

    public func require(_ operation: ECOperationName) throws {
        guard supportedOps.contains(operation.rawValue) else {
            throw ECOperationError.unsupportedOperation(operation.rawValue)
        }
    }
}

public enum ECOperations {
    public enum OpCode {
        public static let noop: UInt8 = 0x01
        public static let failed: UInt8 = 0x05
        public static let strings: UInt8 = 0x06
        public static let miscData: UInt8 = 0x07
        public static let statRequest: UInt8 = 0x0A
        public static let stats: UInt8 = 0x0C
        public static let addLink: UInt8 = 0x09
        public static let partFilePause: UInt8 = 0x19
        public static let partFileResume: UInt8 = 0x1A
        public static let searchStart: UInt8 = 0x26
        public static let searchStop: UInt8 = 0x27
        public static let searchResults: UInt8 = 0x28
        public static let searchProgress: UInt8 = 0x29
        public static let downloadSearchResult: UInt8 = 0x2A
        public static let getDownloadQueue: UInt8 = 0x0D
        public static let downloadQueue: UInt8 = 0x1F
        public static let getServerList: UInt8 = 0x2C
        public static let serverList: UInt8 = 0x2D
        public static let serverDisconnect: UInt8 = 0x2E
        public static let serverConnect: UInt8 = 0x2F
        public static let serverRemove: UInt8 = 0x30
        public static let serverAdd: UInt8 = 0x31
        public static let partFileDelete: UInt8 = 0x1D
        public static let partFilePrioSet: UInt8 = 0x1C
        public static let partFileSetCat: UInt8 = 0x1E
        public static let renameFile: UInt8 = 0x25
        public static let getUploadQueue: UInt8 = 0x0E
        public static let uploadQueue: UInt8 = 0x20
        public static let getSharedFiles: UInt8 = 0x10
        public static let sharedFiles: UInt8 = 0x22
        public static let sharedFilesReload: UInt8 = 0x23
        public static let getStatsGraphs: UInt8 = 0x44
        public static let statsGraphs: UInt8 = 0x45
        public static let getStatsTree: UInt8 = 0x46
        public static let statsTree: UInt8 = 0x47
        public static let kadStart: UInt8 = 0x48
        public static let kadStop: UInt8 = 0x49
        public static let kadBootstrapFromIP: UInt8 = 0x4E
        public static let kadUpdateFromURL: UInt8 = 0x4D
        public static let getPreferences: UInt8 = 0x3F
        public static let setPreferences: UInt8 = 0x40
        public static let createCategory: UInt8 = 0x41
        public static let updateCategory: UInt8 = 0x42
        public static let deleteCategory: UInt8 = 0x43
        public static let ipfilterReload: UInt8 = 0x2B
        public static let ipfilterUpdate: UInt8 = 0x51
        public static let getLog: UInt8 = 0x35
        public static let log: UInt8 = 0x38
        public static let getDebugLog: UInt8 = 0x36
        public static let debugLog: UInt8 = 0x39
        public static let clearCompleted: UInt8 = 0x53
        public static let friend: UInt8 = 0x57
        public static let connect: UInt8 = 0x4A
        public static let disconnect: UInt8 = 0x4B
        public static let getUpdate: UInt8 = 0x52
        public static let serverUpdateFromURL: UInt8 = 0x32
    }

    public enum DetailLevel: UInt64 {
        case command = 0x00
        case full = 0x02
        case incrementalUpdate = 0x04
    }

    public enum TagName {
        public static let detailLevel: UInt16 = 0x0004
        public static let string: UInt16 = 0x0000
        public static let partFile: UInt16 = 0x0300
        public static let partFileName: UInt16 = 0x0301
        public static let partFilePriority: UInt16 = 0x0309
        public static let partFileCategory: UInt16 = 0x030F
        public static let knownFile: UInt16 = 0x0400
        public static let ecid: UInt16 = 0x000F
        public static let server: UInt16 = 0x0500
        public static let serverName: UInt16 = 0x0501
        public static let serverAddress: UInt16 = 0x0503
        public static let serverIP: UInt16 = 0x050C
        public static let serverPort: UInt16 = 0x050D
        public static let searchType: UInt16 = 0x0701
        public static let searchName: UInt16 = 0x0702
        public static let searchFileType: UInt16 = 0x0705
        public static let selectPrefs: UInt16 = 0x1000
        public static let prefsConnections: UInt16 = 0x1300
        public static let connMaxDownload: UInt16 = 0x1303
        public static let connMaxUpload: UInt16 = 0x1304
        public static let serversUpdateURL: UInt16 = 0x170C
        public static let kademliaUpdateURL: UInt16 = 0x1E01
    }

    public enum SearchScope: UInt64 {
        case local = 0x00
        case global = 0x01
        case kad = 0x02

        init(_ scope: String) {
            switch scope.lowercased() {
            case "local": self = .local
            case "global": self = .global
            default: self = .kad
            }
        }
    }

    private static let prefsConnections: UInt64 = 0x04

    public static let readOnlyOperations: [String] = ECSupportedOps.allOperations

    public static func capabilities() -> ECCapabilities {
        ECCapabilities(ops: readOnlyOperations)
    }

    public static func status(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.status)
        return request(opcode: OpCode.statRequest, detail: .command)
    }

    public static func downloads(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.downloads)
        return request(opcode: OpCode.getDownloadQueue, detail: .full)
    }

    public static func servers(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.servers)
        return request(opcode: OpCode.getServerList, detail: .full)
    }

    public static func sourcesQueueLookup(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.sources)
        return request(opcode: OpCode.getDownloadQueue, detail: .command)
    }

    public static func sourcesUpdate(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.sources)
        return request(opcode: OpCode.getUpdate, detail: .incrementalUpdate)
    }

    public static func sources(hash: String, gate: ECCapabilityGate? = nil) throws -> [ECPacket] {
        guard isValidMD4Hash(hash) else { throw ECOperationError.invalidHash(hash) }
        return [try sourcesQueueLookup(gate: gate), try sourcesUpdate(gate: gate)]
    }

    public static func search(scope: String, query: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.search)
        return ECPacket(opcode: OpCode.searchStart, tags: [
            ECTag.integer(name: TagName.searchType, value: SearchScope(scope).rawValue, children: [
                ECTag(name: TagName.searchName, type: .string, value: .string(query)),
                ECTag(name: TagName.searchFileType, type: .string, value: .string("")),
            ]),
        ])
    }

    public static func searchStop(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.searchStop)
        return ECPacket(opcode: OpCode.searchStop)
    }

    public static func searchProgress() -> ECPacket {
        ECPacket(opcode: OpCode.searchProgress)
    }

    public static func searchResults() -> ECPacket {
        request(opcode: OpCode.searchResults, detail: .full)
    }

    public static func download(hash: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.download)
        return ECPacket(opcode: OpCode.downloadSearchResult, tags: [
            ECTag(name: TagName.partFile, type: .hash16, value: .hash16(try hashData(hash)), children: [
                ECTag.integer(name: TagName.partFileCategory, value: 0),
            ]),
        ])
    }

    public static func addLink(_ link: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.addLink)
        return ECPacket(opcode: OpCode.addLink, tags: [ECTag(name: TagName.string, type: .string, value: .string(normalizedED2KLink(link)))])
    }

    public static func pause(hash: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try partFileAction(opcode: OpCode.partFilePause, operation: .pause, hash: hash, gate: gate)
    }

    public static func resume(hash: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try partFileAction(opcode: OpCode.partFileResume, operation: .resume, hash: hash, gate: gate)
    }

    public static func cancel(hash: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try partFileAction(opcode: OpCode.partFileDelete, operation: .cancel, hash: hash, gate: gate)
    }

    public static func rename(hash: String, name: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.rename)
        return ECPacket(opcode: OpCode.renameFile, tags: [
            ECTag(name: TagName.knownFile, type: .hash16, value: .hash16(try hashData(hash))),
            ECTag(name: TagName.partFileName, type: .string, value: .string(name)),
        ])
    }

    public static func priority(hash: String, value: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.priority)
        return ECPacket(opcode: OpCode.partFilePrioSet, tags: [
            ECTag(name: TagName.partFile, type: .hash16, value: .hash16(try hashData(hash)), children: [
                ECTag.integer(name: TagName.partFilePriority, value: UInt64(max(0, value))),
            ]),
        ])
    }

    public static func clearCompleted(ecids: [Int] = [], gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.clearCompleted)
        return ECPacket(opcode: OpCode.clearCompleted, tags: ecids.map { ecid in
            ECTag.integer(name: TagName.ecid, value: UInt64(max(0, ecid)))
        })
    }

    public static func coreConnect(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.connect)
        return ECPacket(opcode: OpCode.connect)
    }

    public static func coreDisconnect(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.disconnect)
        return ECPacket(opcode: OpCode.disconnect)
    }

    public static func serverConnect(ip: String? = nil, port: Int? = nil, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverConnect)
        guard let ip, !ip.isEmpty, let port else { return ECPacket(opcode: OpCode.serverConnect) }
        return ECPacket(opcode: OpCode.serverConnect, tags: [try serverTag(ip: ip, port: port)])
    }

    public static func serverDisconnect(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverDisconnect)
        return ECPacket(opcode: OpCode.serverDisconnect)
    }

    public static func serverAdd(address: String, name: String? = nil, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverAdd)
        var tags = [ECTag(name: TagName.serverAddress, type: .string, value: .string(address))]
        if let name, !name.isEmpty {
            tags.append(ECTag(name: TagName.serverName, type: .string, value: .string(name)))
        }
        return ECPacket(opcode: OpCode.serverAdd, tags: tags)
    }

    public static func serverRemove(ip: String, port: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverRemove)
        return ECPacket(opcode: OpCode.serverRemove, tags: [try serverTag(ip: ip, port: port)])
    }

    public static func serverUpdateFromURL(url: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverUpdateFromURL)
        return ECPacket(opcode: OpCode.serverUpdateFromURL, tags: [
            ECTag(name: TagName.serversUpdateURL, type: .string, value: .string(url))
        ])
    }

    public static func kadStart(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.kadStart)
        return ECPacket(opcode: OpCode.kadStart)
    }

    public static func kadStop(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.kadStop)
        return ECPacket(opcode: OpCode.kadStop)
    }

    public static func kadBootstrap(ip: String, port: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.kadBootstrap)
        let parts = ip.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4, (1...65535).contains(port) else {
            throw ECOperationError.invalidServerEndpoint("\(ip):\(port)")
        }
        return ECPacket(opcode: OpCode.kadBootstrapFromIP, tags: [
            ECTag(name: TagName.serverIP, type: .ipv4, value: .ipv4(ECIPv4Address(parts[0], parts[1], parts[2], parts[3], port: UInt16(port))))
        ])
    }

    public static func kadUpdateFromURL(url: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.kadUpdateFromURL)
        return ECPacket(opcode: OpCode.kadUpdateFromURL, tags: [
            ECTag(name: TagName.kademliaUpdateURL, type: .string, value: .string(url))
        ])
    }

    public static func prefsConnectionGet(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.prefsConnectionGet)
        return ECPacket(opcode: OpCode.getPreferences, tags: [
            ECTag.integer(name: TagName.detailLevel, value: DetailLevel.command.rawValue),
            ECTag.integer(name: TagName.selectPrefs, value: prefsConnections),
        ])
    }

    public static func prefsConnectionSet(maxDownload: Int?, maxUpload: Int?, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.prefsConnectionSet)
        var prefsChildren: [ECTag] = []
        if let maxDownload { prefsChildren.append(ECTag.integer(name: TagName.connMaxDownload, value: UInt64(max(0, maxDownload)))) }
        if let maxUpload { prefsChildren.append(ECTag.integer(name: TagName.connMaxUpload, value: UInt64(max(0, maxUpload)))) }
        return ECPacket(opcode: OpCode.setPreferences, tags: [
            ECTag.integer(name: TagName.selectPrefs, value: prefsConnections),
            ECTag(name: TagName.prefsConnections, type: .custom, children: prefsChildren),
        ])
    }

    private static func request(opcode: UInt8, detail: DetailLevel) -> ECPacket {
        if detail == .full {
            return ECPacket(opcode: opcode)
        }
        return ECPacket(opcode: opcode, tags: [ECTag.integer(name: TagName.detailLevel, value: detail.rawValue)])
    }

    private static func isValidMD4Hash(_ hash: String) -> Bool {
        hash.count == 32 && hash.allSatisfy { $0.isHexDigit }
    }

    private static func hashData(_ hash: String) throws -> Data {
        guard isValidMD4Hash(hash) else { throw ECOperationError.invalidHash(hash) }
        var bytes = Data(capacity: 16)
        var index = hash.startIndex
        while index < hash.endIndex {
            let next = hash.index(index, offsetBy: 2)
            bytes.append(UInt8(hash[index..<next], radix: 16)!)
            index = next
        }
        return bytes
    }

    private static func partFileAction(opcode: UInt8, operation: ECOperationName, hash: String, gate: ECCapabilityGate?) throws -> ECPacket {
        try gate?.require(operation)
        return ECPacket(opcode: opcode, tags: [ECTag(name: TagName.partFile, type: .hash16, value: .hash16(try hashData(hash)))])
    }

    private static func serverTag(ip: String, port: Int) throws -> ECTag {
        let parts = ip.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4, (1...65535).contains(port) else {
            throw ECOperationError.invalidServerEndpoint("\(ip):\(port)")
        }
        return ECTag(name: TagName.server, type: .ipv4, value: .ipv4(ECIPv4Address(parts[0], parts[1], parts[2], parts[3], port: UInt16(port))))
    }

    private static func normalizedED2KLink(_ link: String) -> String {
        var normalized = link
        if normalized.hasPrefix("ed2k://") {
            if normalized.contains("|h="), !normalized.contains("|/|h=") {
                normalized = normalized.replacingOccurrences(of: "|h=", with: "|/|h=")
            }
            if normalized.hasPrefix("ed2k://%7C") {
                normalized = normalized.replacingOccurrences(of: "%7C", with: "|")
            }
        }
        return normalized
    }
}
