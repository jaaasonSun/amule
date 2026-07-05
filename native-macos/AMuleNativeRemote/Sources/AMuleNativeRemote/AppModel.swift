import Foundation
import SharedViews
import SwiftUI
import AMuleECBridgeAdapter
import SharedModels
import SharedServices

struct DownloadRenameSuggestionRequest: Equatable {
    let downloadID: String
    let suggestion: String
}

func L3(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func LF3(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

@MainActor
final class AppModel: ObservableObject {
    @AppStorage("amule.host") var host: String = "127.0.0.1"
    @AppStorage("amule.port") var port: Int = 4712
    @Published var password: String {
        didSet {
            persistPassword()
        }
    }
    @AppStorage("amule.prefs.connection.maxDownload") var savedConnectionMaxDownload: Int = 0
    @AppStorage("amule.prefs.connection.maxUpload") var savedConnectionMaxUpload: Int = 0

    @Published var status: StatusSnapshot = .init()
    @Published var isSessionConnected = false
    @Published var searchQuery: String = ""
    @Published var searchScope: String = "global"
    @Published var searchOptions = SearchOptions()
    @Published var searchResults: [SearchResult] = []
    @Published var searchProgress: Int = 0
    @Published var isSearchInProgress = false
    @Published var lastSearchRawOutput = ""
    @Published var downloads: [DownloadItem] = []
    @Published var downloadSourcesByHash: [String: [DownloadSourceItem]] = [:]
    @Published var servers: [ServerItem] = []
    @Published var serverAddressInput: String = ""
    @Published var serverNameInput: String = ""
    @Published var isBusy = false
    @Published var outputLog = ""
    @Published var lastDownloadsRawOutput = ""
    @Published var lastSourcesRawOutput = ""
    @Published var lastUploadsRawOutput = ""
    @Published var lastSharedFilesRawOutput = ""
    @Published var lastCoreLogRawOutput = ""
    @Published var lastCoreDebugLogRawOutput = ""
    @Published var lastServerInfoRawOutput = ""
    @Published var lastConnectionPrefsRawOutput = ""
    @Published var lastCategoriesRawOutput = ""
    @Published var lastFriendsRawOutput = ""
    @Published var lastStatsTreeRawOutput = ""
    @Published var lastStatsGraphsRawOutput = ""
    @Published var lastServersRawOutput = ""
    @Published var lastError = ""
    @Published var isRefreshingSources = false
    @Published var shouldAutoRefreshDownloads = false
    @Published var addLinksPanelRequestID: Int = 0
    @Published var selectedDownloadID: String? = nil
    @Published var renameSuggestionRequestID: Int = 0
    @Published var hudMessage: String = ""
    @Published var showHUD = false
    @Published var bridgeSchemaVersion: Int?
    @Published var bridgeOps: Set<String> = []
    @Published var uploads: [BridgeUploadPayload] = []
    @Published var sharedFiles: [BridgeSharedFilePayload] = []
    @Published var coreLogLines: [String] = []
    @Published var coreDebugLogLines: [String] = []
    @Published var serverInfoLines: [String] = []
    @Published var connectionMaxDownloadKBps: Int = 0
    @Published var connectionMaxUploadKBps: Int = 0
    @Published var connectionMaxDownloadInput: String = "0"
    @Published var connectionMaxUploadInput: String = "0"
    @Published var categories: [BridgeCategoryPayload] = []
    @Published var friends: [BridgeFriendPayload] = []
    @Published var statsTree: BridgeStatsTreeNodePayload?
    @Published var statsGraphs: BridgeStatsGraphsPayload?
    @Published var statsGraphsLastTimestamp: Double?
    @Published var ipFilterURLInput: String = ""

    var autoRefreshTask: Task<Void, Never>?
    var pendingRenameSuggestionRequest: DownloadRenameSuggestionRequest?
    var hudDismissTask: Task<Void, Never>?
    var searchTask: Task<Void, Never>?
    var renameVerificationMaxAttempts = 3
    var renameVerificationRetryDelayNanoseconds: UInt64 = 300_000_000
    let pasteboardShare: PasteboardShare
    let bridge: BridgeProtocol
    let serverManagementService: ServerManagementService
    private let credentialStorage: CredentialStorage
    private let passwordStorageKey = "amule.password"

    var buildCommit: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "AMuleBuildCommit") as? String,
           !value.isEmpty {
            return value
        }
        return "dev"
    }

    var config: AMuleConnectionConfig {
        .init(host: host, port: port, password: password)
    }

    init(
        pasteboardShare: PasteboardShare = platformDefaultPasteboardShare(),
        bridge: BridgeProtocol = platformDefaultBridgeAdapter(),
        credentialStorage: CredentialStorage = platformDefaultCredentialStorage(),
        defaults: UserDefaults = .standard
    ) {
        self.pasteboardShare = pasteboardShare
        self.bridge = bridge
        self.serverManagementService = ServerManagementService(bridge: bridge)
        self.credentialStorage = credentialStorage
        let legacyPassword = defaults.string(forKey: passwordStorageKey)
        let keychainPassword = credentialStorage.readCredential(forKey: passwordStorageKey)
        self.password = keychainPassword ?? legacyPassword ?? ""
        if keychainPassword == nil, let legacyPassword {
            if legacyPassword.isEmpty {
                credentialStorage.deleteCredential(forKey: passwordStorageKey)
            } else {
                credentialStorage.writeCredential(legacyPassword, forKey: passwordStorageKey)
            }
        }
        if defaults.object(forKey: passwordStorageKey) != nil {
            defaults.removeObject(forKey: passwordStorageKey)
        }
        connectionMaxDownloadKBps = savedConnectionMaxDownload
        connectionMaxUploadKBps = savedConnectionMaxUpload
        connectionMaxDownloadInput = String(savedConnectionMaxDownload)
        connectionMaxUploadInput = String(savedConnectionMaxUpload)

        for argument in CommandLine.arguments.dropFirst() {
            PendingIncomingLinkInbox.shared.enqueue(argument)
        }
    }

    func isBridgeOpSupported(_ op: String) -> Bool {
        BridgeCapabilityGate.isSupported(op, by: bridgeOps)
    }

    private func persistPassword() {
        if password.isEmpty {
            credentialStorage.deleteCredential(forKey: passwordStorageKey)
        } else {
            credentialStorage.writeCredential(password, forKey: passwordStorageKey)
        }
    }
}
