import Foundation
import AMuleECClient
import AMuleECBridgeAdapter
import SharedViews
import SharedModels
import SharedServices

extension AppModel {
    func refreshConnectionPrefs() {
        guard isBridgeOpSupported("prefs-connection-get") else { return }
        run(label: "prefs-connection-get") {
            try await self.refreshConnectionPrefsNow()
        }
    }

    func setConnectionSpeedLimits(maxDL rawMaxDL: String, maxUL rawMaxUL: String) {
        guard isBridgeOpSupported("prefs-connection-set") else { return }

        let prefs: BridgeConnectionPrefsPayload
        do {
            let limits = try TransferLimitSettings(downloadText: rawMaxDL, uploadText: rawMaxUL)
            let tcpPort = try validatePort(connectionTCPPortInput, label: L3("TCP port"), allowEmpty: true)
            let udpPort = try validatePort(connectionUDPPortInput, label: L3("UDP port"), allowEmpty: true)
            prefs = BridgeConnectionPrefsPayload(
                maxDownload: limits.maxDownload,
                maxUpload: limits.maxUpload,
                tcpPort: tcpPort,
                udpPort: udpPort,
                udpEnabled: connectionUDPEnabled,
                ed2kEnabled: connectionED2KEnabled,
                kadEnabled: connectionKADEnabled
            )
        } catch TransferLimitValidationError.invalidDownload {
            lastError = L3("Invalid download speed limit. Use a non-negative integer.")
            return
        } catch TransferLimitValidationError.invalidUpload {
            lastError = L3("Invalid upload speed limit. Use a non-negative integer.")
            return
        } catch PreferenceValidationError.invalidValue(let message) {
            lastError = message
            return
        } catch {
            lastError = error.localizedDescription
            return
        }

        run(label: "prefs-connection-set") {
            let (_, raw) = try await self.bridge.prefsConnectionSet(prefs: prefs, group: .connection, config: self.config)
            await MainActor.run {
                self.appendLog("$ prefs-connection-set --group connection\n\(raw)")
            }
            if self.isBridgeOpSupported("prefs-connection-get") {
                try await self.refreshConnectionPrefsNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func setDirectoriesPrefs(incoming rawIncoming: String, temp rawTemp: String, sharedDirectories rawSharedDirectories: String) {
        guard isBridgeOpSupported("prefs-connection-set") else { return }
        let incoming = rawIncoming.trimmingCharacters(in: .whitespacesAndNewlines)
        let temp = rawTemp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !incoming.isEmpty else {
            lastError = L3("Incoming directory is required.")
            return
        }
        guard !temp.isEmpty else {
            lastError = L3("Temp directory is required.")
            return
        }
        let sharedDirectories = rawSharedDirectories
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let prefs = BridgeConnectionPrefsPayload(
            maxDownload: 0,
            maxUpload: 0,
            incomingDirectory: incoming,
            tempDirectory: temp,
            sharedDirectories: sharedDirectories,
            shareHiddenFiles: shareHiddenFiles
        )
        applyPreferenceGroup(.directories, prefs: prefs, logGroup: "directories")
    }

    func setFilePrefs() {
        guard isBridgeOpSupported("prefs-connection-set") else { return }
        let minFreeDiskSpace: Int
        do {
            minFreeDiskSpace = try validateNonNegativeInteger(minFreeDiskSpaceInput, label: L3("Minimum free disk space"))
        } catch PreferenceValidationError.invalidValue(let message) {
            lastError = message
            return
        } catch {
            lastError = error.localizedDescription
            return
        }
        let prefs = BridgeConnectionPrefsPayload(
            maxDownload: 0,
            maxUpload: 0,
            newFilesPaused: newFilesPaused,
            autoDownloadPriority: autoDownloadPriority,
            previewPriority: previewPriority,
            autoUploadPriority: autoUploadPriority,
            saveSources: saveSources,
            extractMetadata: extractMetadata,
            allocateFullFileSize: allocateFullFileSize,
            checkFreeSpace: checkFreeSpace,
            minFreeDiskSpaceMB: minFreeDiskSpace,
            createSparseFiles: createSparseFiles
        )
        applyPreferenceGroup(.files, prefs: prefs, logGroup: "files")
    }

    func setServersPrefs() {
        guard isBridgeOpSupported("prefs-connection-set") else { return }
        let retries: Int
        do {
            retries = try validateNonNegativeInteger(deadServerRetriesInput, label: L3("Dead server retries"))
        } catch PreferenceValidationError.invalidValue(let message) {
            lastError = message
            return
        } catch {
            lastError = error.localizedDescription
            return
        }
        let prefs = BridgeConnectionPrefsPayload(
            maxDownload: 0,
            maxUpload: 0,
            serverUpdateURL: serverUpdateURLInput.trimmingCharacters(in: .whitespacesAndNewlines),
            removeDeadServers: removeDeadServers,
            deadServerRetries: retries,
            autoUpdateServers: autoUpdateServers,
            addServersFromServer: addServersFromServer,
            addServersFromClient: addServersFromClient,
            useServerPrioritySystem: useServerPrioritySystem,
            smartIdCheck: smartIDCheck,
            safeServerConnect: safeServerConnect,
            autoConnectStaticOnly: autoConnectStaticOnly,
            manualHighPriority: manualHighPriority
        )
        applyPreferenceGroup(.servers, prefs: prefs, logGroup: "servers")
    }

    func setSecurityPrefs() {
        guard isBridgeOpSupported("prefs-connection-set") else { return }
        let level: Int
        do {
            level = try validateIntegerRange(ipFilterLevelInput, label: L3("IP filter level"), range: 0...255)
        } catch PreferenceValidationError.invalidValue(let message) {
            lastError = message
            return
        } catch {
            lastError = error.localizedDescription
            return
        }
        let prefs = BridgeConnectionPrefsPayload(
            maxDownload: 0,
            maxUpload: 0,
            ipFilterLevel: level,
            filterClients: filterClients,
            filterServers: filterServers,
            ipFilterAutoUpdate: ipFilterAutoUpdate,
            ipFilterUpdateURL: ipFilterUpdateURLInput.trimmingCharacters(in: .whitespacesAndNewlines),
            filterLanIPs: filterLanIPs,
            secureIdentEnabled: secureIdentEnabled,
            obfuscationSupported: obfuscationSupported,
            obfuscationRequested: obfuscationRequested,
            obfuscationRequired: obfuscationRequired
        )
        applyPreferenceGroup(.security, prefs: prefs, logGroup: "security")
    }

    func setRemoteControlPrefs() {
        guard isBridgeOpSupported("prefs-connection-set") else { return }
        let port: Int
        let refresh: Int
        do {
            port = try validatePort(webServerPortInput, label: L3("Webserver port"), allowEmpty: false) ?? 0
            refresh = try validateNonNegativeInteger(webServerRefreshInput, label: L3("Webserver refresh"))
        } catch PreferenceValidationError.invalidValue(let message) {
            lastError = message
            return
        } catch {
            lastError = error.localizedDescription
            return
        }
        let prefs = BridgeConnectionPrefsPayload(
            maxDownload: 0,
            maxUpload: 0,
            webServerEnabled: webServerEnabled,
            webServerPort: port,
            webServerGuestEnabled: webServerGuestEnabled,
            webServerUseGzip: webServerUseGzip,
            webServerRefreshSeconds: refresh,
            webServerTemplate: webServerTemplateInput.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        applyPreferenceGroup(.remoteControls, prefs: prefs, logGroup: "remote-controls")
    }

    func refreshConnectionPrefsNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await bridge.prefsConnectionGet(config: config)
            await MainActor.run {
                self.connectionMaxDownloadKBps = payload.maxDownload
                self.connectionMaxUploadKBps = payload.maxUpload
                self.connectionMaxDownloadInput = String(payload.maxDownload)
                self.connectionMaxUploadInput = String(payload.maxUpload)
                self.savedConnectionMaxDownload = payload.maxDownload
                self.savedConnectionMaxUpload = payload.maxUpload
                if let tcpPort = payload.tcpPort {
                    self.connectionTCPPort = tcpPort
                    self.connectionTCPPortInput = String(tcpPort)
                }
                if let udpPort = payload.udpPort {
                    self.connectionUDPPort = udpPort
                    self.connectionUDPPortInput = String(udpPort)
                }
                self.connectionUDPEnabled = payload.udpEnabled ?? self.connectionUDPEnabled
                self.connectionED2KEnabled = payload.ed2kEnabled ?? self.connectionED2KEnabled
                self.connectionKADEnabled = payload.kadEnabled ?? self.connectionKADEnabled
                self.incomingDirectoryInput = payload.incomingDirectory ?? self.incomingDirectoryInput
                self.tempDirectoryInput = payload.tempDirectory ?? self.tempDirectoryInput
                if let sharedDirectories = payload.sharedDirectories {
                    self.sharedDirectoriesInput = sharedDirectories.joined(separator: "\n")
                }
                self.shareHiddenFiles = payload.shareHiddenFiles ?? self.shareHiddenFiles
                self.newFilesPaused = payload.newFilesPaused ?? self.newFilesPaused
                self.autoDownloadPriority = payload.autoDownloadPriority ?? self.autoDownloadPriority
                self.previewPriority = payload.previewPriority ?? self.previewPriority
                self.autoUploadPriority = payload.autoUploadPriority ?? self.autoUploadPriority
                self.saveSources = payload.saveSources ?? self.saveSources
                self.extractMetadata = payload.extractMetadata ?? self.extractMetadata
                self.allocateFullFileSize = payload.allocateFullFileSize ?? self.allocateFullFileSize
                self.checkFreeSpace = payload.checkFreeSpace ?? self.checkFreeSpace
                self.minFreeDiskSpaceInput = payload.minFreeDiskSpaceMB.map(String.init) ?? self.minFreeDiskSpaceInput
                self.createSparseFiles = payload.createSparseFiles ?? self.createSparseFiles
                self.serverUpdateURLInput = payload.serverUpdateURL ?? self.serverUpdateURLInput
                self.removeDeadServers = payload.removeDeadServers ?? self.removeDeadServers
                self.deadServerRetriesInput = payload.deadServerRetries.map(String.init) ?? self.deadServerRetriesInput
                self.autoUpdateServers = payload.autoUpdateServers ?? self.autoUpdateServers
                self.addServersFromServer = payload.addServersFromServer ?? self.addServersFromServer
                self.addServersFromClient = payload.addServersFromClient ?? self.addServersFromClient
                self.useServerPrioritySystem = payload.useServerPrioritySystem ?? self.useServerPrioritySystem
                self.smartIDCheck = payload.smartIdCheck ?? self.smartIDCheck
                self.safeServerConnect = payload.safeServerConnect ?? self.safeServerConnect
                self.autoConnectStaticOnly = payload.autoConnectStaticOnly ?? self.autoConnectStaticOnly
                self.manualHighPriority = payload.manualHighPriority ?? self.manualHighPriority
                self.ipFilterLevelInput = payload.ipFilterLevel.map(String.init) ?? self.ipFilterLevelInput
                self.filterClients = payload.filterClients ?? self.filterClients
                self.filterServers = payload.filterServers ?? self.filterServers
                self.ipFilterAutoUpdate = payload.ipFilterAutoUpdate ?? self.ipFilterAutoUpdate
                self.ipFilterUpdateURLInput = payload.ipFilterUpdateURL ?? self.ipFilterUpdateURLInput
                if self.ipFilterURLInput.isEmpty {
                    self.ipFilterURLInput = payload.ipFilterUpdateURL ?? self.ipFilterURLInput
                }
                self.filterLanIPs = payload.filterLanIPs ?? self.filterLanIPs
                self.secureIdentEnabled = payload.secureIdentEnabled ?? self.secureIdentEnabled
                self.obfuscationSupported = payload.obfuscationSupported ?? self.obfuscationSupported
                self.obfuscationRequested = payload.obfuscationRequested ?? self.obfuscationRequested
                self.obfuscationRequired = payload.obfuscationRequired ?? self.obfuscationRequired
                self.webServerEnabled = payload.webServerEnabled ?? self.webServerEnabled
                self.webServerPortInput = payload.webServerPort.map(String.init) ?? self.webServerPortInput
                self.webServerGuestEnabled = payload.webServerGuestEnabled ?? self.webServerGuestEnabled
                self.webServerUseGzip = payload.webServerUseGzip ?? self.webServerUseGzip
                self.webServerRefreshInput = payload.webServerRefreshSeconds.map(String.init) ?? self.webServerRefreshInput
                self.webServerTemplateInput = payload.webServerTemplate ?? self.webServerTemplateInput
                self.remotePrefsStatisticsSupported = payload.statisticsSupported
                self.lastConnectionPrefsRawOutput = raw
                if logOutput {
                    self.appendLog("$ prefs-connection-get\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func applyPreferenceGroup(_ group: ECOperations.PreferencesGroup, prefs: BridgeConnectionPrefsPayload, logGroup: String) {
        run(label: "prefs-connection-set") {
            let (_, raw) = try await self.bridge.prefsConnectionSet(prefs: prefs, group: group, config: self.config)
            await MainActor.run {
                self.appendLog("$ prefs-connection-set --group \(logGroup)\n\(raw)")
            }
            if self.isBridgeOpSupported("prefs-connection-get") {
                try await self.refreshConnectionPrefsNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    private func validatePort(_ rawValue: String, label: String, allowEmpty: Bool) throws -> Int? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, allowEmpty { return nil }
        let value = try validateNonNegativeInteger(trimmed, label: label)
        guard (1...65535).contains(value) else {
            throw PreferenceValidationError.invalidValue(LF3("%@ must be between 1 and 65535.", label))
        }
        return value
    }

    private func validateNonNegativeInteger(_ rawValue: String, label: String) throws -> Int {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else {
            throw PreferenceValidationError.invalidValue(LF3("%@ must be a non-negative integer.", label))
        }
        return value
    }

    private func validateIntegerRange(_ rawValue: String, label: String, range: ClosedRange<Int>) throws -> Int {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), range.contains(value) else {
            throw PreferenceValidationError.invalidValue(LF3("%@ must be a number from %d to %d.", label, range.lowerBound, range.upperBound))
        }
        return value
    }
}

private enum PreferenceValidationError: Error {
    case invalidValue(String)
}
