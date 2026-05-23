import Foundation
import AMuleECProtocol

public struct ECSourceStateStore: Sendable {
    private var sourcesByClientID: [Int: ECSource] = [:]

    public init() {}

    public mutating func applyIncrementalUpdate(_ packet: ECPacket) {
        for tag in packet.tags.flatMap(Self.clientTags(in:)) {
            applyClientDelta(tag)
        }
    }

    public func sources(for requestFileID: Int) -> [ECSource] {
        sourcesByClientID.values
            .filter { $0.requestFileID == requestFileID }
            .sorted { lhs, rhs in
                if lhs.downloadState != rhs.downloadState { return lhs.downloadState < rhs.downloadState }
                if lhs.downSpeedKBps != rhs.downSpeedKBps { return lhs.downSpeedKBps > rhs.downSpeedKBps }
                if lhs.clientName != rhs.clientName { return lhs.clientName < rhs.clientName }
                return lhs.clientID < rhs.clientID
            }
    }

    private mutating func applyClientDelta(_ tag: ECTag) {
        let clientID = tag.intValue
        guard clientID > 0 else { return }

        if tag.children.isEmpty {
            sourcesByClientID.removeValue(forKey: clientID)
            return
        }

        let existing = sourcesByClientID[clientID]
        let requestFileID = tag.child(named: TagName.clientRequestFile)?.intValue ?? existing?.requestFileID ?? 0
        guard requestFileID > 0 else { return }

        let rank = tag.child(named: TagName.clientRemoteQueueRank)?.intValue ?? existing?.remoteQueueRank ?? 0
        let state = tag.child(named: TagName.clientDownloadState)?.intValue ?? existing?.downloadState ?? 0
        let from = tag.child(named: TagName.clientFrom)?.intValue ?? existing?.sourceFrom ?? 0
        let softwareCode = tag.child(named: TagName.clientSoftware)?.intValue

        sourcesByClientID[clientID] = ECSource(
            clientID: clientID,
            requestFileID: requestFileID,
            clientName: tag.child(named: TagName.clientName)?.stringValue ?? existing?.clientName ?? "",
            userIP: tag.child(named: TagName.clientUserIP)?.ipStringValue ?? existing?.userIP ?? "",
            userPort: tag.child(named: TagName.clientUserPort)?.intValue ?? existing?.userPort ?? 0,
            serverName: tag.child(named: TagName.clientServerName)?.stringValue ?? existing?.serverName ?? "",
            serverIP: tag.child(named: TagName.clientServerIP)?.ipStringValue ?? existing?.serverIP ?? "",
            serverPort: tag.child(named: TagName.clientServerPort)?.intValue ?? existing?.serverPort ?? 0,
            software: softwareCode.map(Self.softwareText) ?? existing?.software ?? "Unknown",
            softwareVersion: tag.child(named: TagName.clientSoftwareVersion)?.stringValue ?? existing?.softwareVersion ?? "",
            downloadState: state,
            downloadStateText: Self.downloadStateText(state, queueFull: rank == 0xffff),
            sourceFrom: from,
            sourceFromText: Self.sourceFromText(from),
            downSpeedKBps: tag.child(named: TagName.clientDownSpeed)?.doubleValue ?? existing?.downSpeedKBps ?? 0,
            availableParts: tag.child(named: TagName.clientAvailableParts)?.intValue ?? existing?.availableParts ?? 0,
            remoteQueueRank: rank,
            obfuscationStatus: tag.child(named: TagName.clientObfuscationStatus)?.intValue ?? existing?.obfuscationStatus ?? 0,
            extendedProtocol: tag.child(named: TagName.clientExtendedProtocol)?.boolValue ?? existing?.extendedProtocol ?? false,
            remoteFilename: tag.child(named: TagName.clientRemoteFilename)?.stringValue ?? existing?.remoteFilename ?? ""
        )
    }

    private static func clientTags(in tag: ECTag) -> [ECTag] {
        guard tag.name == TagName.client else { return [] }
        let nested = tag.children.filter { $0.name == TagName.client }
        return nested.isEmpty ? [tag] : nested
    }

    private static func softwareText(_ code: Int) -> String {
        code == 0 ? "Unknown" : String(code)
    }

    private static func sourceFromText(_ code: Int) -> String {
        switch code {
        case 0: return "None"
        case 1: return "Server"
        case 2: return "Kad"
        case 3: return "Source exchange"
        case 4: return "Passive"
        default: return String(code)
        }
    }

    private static func downloadStateText(_ code: Int, queueFull: Bool) -> String {
        if queueFull { return "Remote queue full" }
        switch code {
        case 0: return "None"
        case 1: return "Connecting"
        case 2: return "On queue"
        case 3: return "Downloading"
        case 4: return "No needed parts"
        default: return String(code)
        }
    }

    private enum TagName {
        static let client: UInt16 = 0x0600
        static let clientSoftware: UInt16 = 0x0601
        static let clientName: UInt16 = 0x0100
        static let clientDownloadState: UInt16 = 0x060C
        static let clientDownSpeed: UInt16 = 0x060E
        static let clientFrom: UInt16 = 0x060F
        static let clientUserIP: UInt16 = 0x0610
        static let clientUserPort: UInt16 = 0x0611
        static let clientServerIP: UInt16 = 0x0612
        static let clientServerPort: UInt16 = 0x0613
        static let clientServerName: UInt16 = 0x0614
        static let clientSoftwareVersion: UInt16 = 0x0615
        static let clientObfuscationStatus: UInt16 = 0x0618
        static let clientRemoteQueueRank: UInt16 = 0x061A
        static let clientExtendedProtocol: UInt16 = 0x061D
        static let clientRequestFile: UInt16 = 0x0620
        static let clientRemoteFilename: UInt16 = 0x0627
        static let clientAvailableParts: UInt16 = 0x062A
    }
}

private extension ECTag {
    func child(named name: UInt16) -> ECTag? {
        children.first { $0.name == name }
    }

    var uintValue: UInt64? {
        if case .uint(let value) = value { return value }
        return nil
    }

    var intValue: Int {
        Int(uintValue ?? 0)
    }

    var stringValue: String? {
        if case .string(let value) = value { return value }
        return nil
    }

    var doubleValue: Double? {
        switch value {
        case .double(let value): return value
        case .uint(let value): return Double(value)
        default: return nil
        }
    }

    var boolValue: Bool? {
        guard let uintValue else { return nil }
        return uintValue != 0
    }

    var ipv4Value: (host: String, port: Int)? {
        if case .ipv4(let value) = value {
            return ("\(value.octets.0).\(value.octets.1).\(value.octets.2).\(value.octets.3)", Int(value.port))
        }
        return nil
    }

    var ipStringValue: String? {
        if let endpoint = ipv4Value { return endpoint.host }
        guard let raw = uintValue, raw != 0 else { return nil }
        return [24, 16, 8, 0]
            .map { String((raw >> UInt64($0)) & 0xff) }
            .joined(separator: ".")
    }
}
