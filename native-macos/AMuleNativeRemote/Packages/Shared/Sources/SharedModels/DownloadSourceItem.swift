import Foundation
import AMuleECClient
import AMuleECBridgeAdapter

public struct DownloadSourceItem: Identifiable, Hashable, Sendable {
    public let id: Int
    public let requestFileID: Int
    public let clientName: String
    public let userIP: String
    public let userPort: Int
    public let serverName: String
    public let serverIP: String
    public let serverPort: Int
    public let software: String
    public let softwareVersion: String
    public let downloadState: Int
    public let downloadStateText: String
    public let sourceFrom: Int
    public let sourceFromText: String
    public let downSpeedKBps: Double
    public let availableParts: Int
    public let remoteQueueRank: Int
    public let obfuscationStatus: Int
    public let extendedProtocol: Bool
    public let remoteFilename: String
    public let downloadedTotal: Int?
    public let uploadedTotal: Int?
    public let versionString: String?
    public let sharesFileList: Bool?

    public init(
        id: Int,
        requestFileID: Int,
        clientName: String,
        userIP: String,
        userPort: Int,
        serverName: String,
        serverIP: String,
        serverPort: Int,
        software: String,
        softwareVersion: String,
        downloadState: Int,
        downloadStateText: String,
        sourceFrom: Int,
        sourceFromText: String,
        downSpeedKBps: Double,
        availableParts: Int,
        remoteQueueRank: Int,
        obfuscationStatus: Int,
        extendedProtocol: Bool,
        remoteFilename: String,
        downloadedTotal: Int? = nil,
        uploadedTotal: Int? = nil,
        versionString: String? = nil,
        sharesFileList: Bool? = nil
    ) {
        self.id = id
        self.requestFileID = requestFileID
        self.clientName = clientName
        self.userIP = userIP
        self.userPort = userPort
        self.serverName = serverName
        self.serverIP = serverIP
        self.serverPort = serverPort
        self.software = software
        self.softwareVersion = softwareVersion
        self.downloadState = downloadState
        self.downloadStateText = downloadStateText
        self.sourceFrom = sourceFrom
        self.sourceFromText = sourceFromText
        self.downSpeedKBps = downSpeedKBps
        self.availableParts = availableParts
        self.remoteQueueRank = remoteQueueRank
        self.obfuscationStatus = obfuscationStatus
        self.extendedProtocol = extendedProtocol
        self.remoteFilename = remoteFilename
        self.downloadedTotal = downloadedTotal
        self.uploadedTotal = uploadedTotal
        self.versionString = versionString
        self.sharesFileList = sharesFileList
    }

    public var clientDisplayName: String {
        clientName.isEmpty ? "(unknown client)" : clientName
    }

    public var endpoint: String {
        if !userIP.isEmpty, userPort > 0 {
            return "\(userIP):\(userPort)"
        }
        if !userIP.isEmpty {
            return userIP
        }
        return "-"
    }

    public var serverEndpoint: String {
        let endpoint: String
        if !serverIP.isEmpty, serverPort > 0 {
            endpoint = "\(serverIP):\(serverPort)"
        } else if !serverIP.isEmpty {
            endpoint = serverIP
        } else {
            endpoint = "-"
        }

        if serverName.isEmpty {
            return endpoint
        }
        return serverName + (endpoint == "-" ? "" : " (\(endpoint))")
    }

    public var softwareDisplay: String {
        if softwareVersion.isEmpty {
            return software
        }
        return "\(software) \(softwareVersion)"
    }

    public var speedText: String {
        guard downSpeedKBps > 0 else { return "-" }
        let bytesPerSecond = Int((downSpeedKBps * 1024.0).rounded())
        return AMuleFormatter.speed(bytesPerSecond: bytesPerSecond)
    }

    public var downloadedText: String {
        guard let downloadedTotal else { return "-" }
        return AMuleFormatter.fileSize(Int64(downloadedTotal))
    }

    public var uploadedText: String {
        guard let uploadedTotal else { return "-" }
        return AMuleFormatter.fileSize(Int64(uploadedTotal))
    }

    public var versionDisplay: String {
        guard let versionString else { return "-" }
        let trimmedVersion = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedVersion.isEmpty ? "-" : trimmedVersion
    }

    public var sharesFileListText: String {
        guard let sharesFileList else { return "-" }
        return NSLocalizedString(sharesFileList ? "Yes" : "No", comment: "")
    }

    public var queueRankText: String {
        remoteQueueRank == 0xffff ? "Full" : String(remoteQueueRank)
    }

    public static func fromBridge(_ payload: [BridgeDownloadSourcePayload]) -> [DownloadSourceItem] {
        payload.map {
            DownloadSourceItem(
                id: $0.clientID,
                requestFileID: $0.requestFileID,
                clientName: $0.clientName,
                userIP: $0.userIP,
                userPort: $0.userPort,
                serverName: $0.serverName,
                serverIP: $0.serverIP,
                serverPort: $0.serverPort,
                software: $0.software,
                softwareVersion: $0.softwareVersion,
                downloadState: $0.downloadState,
                downloadStateText: $0.downloadStateText,
                sourceFrom: $0.sourceFrom,
                sourceFromText: $0.sourceFromText,
                downSpeedKBps: $0.downSpeedKBps,
                availableParts: $0.availableParts,
                remoteQueueRank: $0.remoteQueueRank,
                obfuscationStatus: $0.obfuscationStatus,
                extendedProtocol: $0.extendedProtocol,
                remoteFilename: $0.remoteFilename,
                downloadedTotal: $0.downloadedTotal,
                uploadedTotal: $0.uploadedTotal,
                versionString: $0.versionString,
                sharesFileList: $0.sharesFileList
            )
        }
    }
}
