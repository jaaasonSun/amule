import Foundation
import SharedModels
import SharedServices

extension AppModel {
    func refreshUploads() {
        guard isBridgeOpSupported("uploads") else { return }
        run(label: "uploads") {
            try await self.refreshUploadsNow()
        }
    }

    func refreshSharedFiles() {
        guard isBridgeOpSupported("shared-files") else { return }
        run(label: "shared-files") {
            try await self.refreshSharedFilesNow()
        }
    }

    func reloadSharedFiles() {
        guard isBridgeOpSupported("shared-files-reload") else { return }
        run(label: "shared-files-reload") {
            let (_, raw) = try await self.bridge.sharedFilesReload(config: self.config)
            await MainActor.run {
                self.appendLog("$ shared-files-reload\n\(raw)")
            }
            if self.isBridgeOpSupported("shared-files") {
                try await self.refreshSharedFilesNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func refreshCoreLog() {
        guard isBridgeOpSupported("log") else { return }
        run(label: "log") {
            try await self.refreshCoreLogNow()
        }
    }

    func refreshCoreDebugLog() {
        guard isBridgeOpSupported("debug-log") else { return }
        run(label: "debug-log") {
            try await self.refreshCoreDebugLogNow()
        }
    }

    func refreshCategories() {
        guard isBridgeOpSupported("categories") else { return }
        run(label: "categories") {
            try await self.refreshCategoriesNow()
        }
    }

    func createCategory(name: String, path: String, comment: String, color: Int, priority: Int) {
        guard isBridgeOpSupported("category-create") else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = L3("Category name is required.")
            return
        }

        run(label: "category-create") {
            let (_, raw) = try await self.bridge.categoryCreate(
                name: trimmed,
                path: path,
                comment: comment,
                color: color,
                priority: priority,
                config: self.config
            )
            await MainActor.run {
                self.appendLog("$ category-create --name \(trimmed)\n\(raw)")
            }
            if self.isBridgeOpSupported("categories") {
                try await self.refreshCategoriesNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func deleteCategory(id: Int) {
        guard isBridgeOpSupported("category-delete") else { return }
        run(label: "category-delete") {
            let (_, raw) = try await self.bridge.categoryDelete(categoryID: id, config: self.config)
            await MainActor.run {
                self.appendLog("$ category-delete --category \(id)\n\(raw)")
            }
            if self.isBridgeOpSupported("categories") {
                try await self.refreshCategoriesNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func refreshFriends() {
        guard isBridgeOpSupported("friends") else { return }
        run(label: "friends") {
            try await self.refreshFriendsNow()
        }
    }

    func removeFriend(id: Int) {
        guard isBridgeOpSupported("friend-remove") else { return }
        run(label: "friend-remove") {
            let (_, raw) = try await self.bridge.friendRemove(friendID: id, config: self.config)
            await MainActor.run {
                self.appendLog("$ friend-remove --friend-id \(id)\n\(raw)")
            }
            if self.isBridgeOpSupported("friends") {
                try await self.refreshFriendsNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func setFriendSlot(id: Int, enabled: Bool) {
        guard isBridgeOpSupported("friend-slot") else { return }
        run(label: "friend-slot") {
            let (_, raw) = try await self.bridge.friendSlot(friendID: id, enabled: enabled, config: self.config)
            await MainActor.run {
                self.appendLog("$ friend-slot --friend-id \(id) --friend-slot \(enabled ? 1 : 0)\n\(raw)")
            }
            if self.isBridgeOpSupported("friends") {
                try await self.refreshFriendsNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func reloadIpFilter() {
        guard isBridgeOpSupported("ipfilter-reload") else { return }
        run(label: "ipfilter-reload") {
            let (_, raw) = try await self.bridge.ipfilterReload(config: self.config)
            await MainActor.run {
                self.appendLog("$ ipfilter-reload\n\(raw)")
            }
        }
    }

    func updateIpFilterFromURL(_ rawURL: String) {
        guard isBridgeOpSupported("ipfilter-update") else { return }
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            guard let url = URL(string: trimmed),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                lastError = L3("Invalid IP filter URL. Use http:// or https://.")
                return
            }
        }

        run(label: "ipfilter-update") {
            let (_, raw) = try await self.bridge.ipfilterUpdate(url: trimmed.isEmpty ? nil : trimmed, config: self.config)
            await MainActor.run {
                if trimmed.isEmpty {
                    self.appendLog("$ ipfilter-update\n\(raw)")
                } else {
                    self.appendLog("$ ipfilter-update --ipfilter-url \(trimmed)\n\(raw)")
                }
            }
        }
    }

    func refreshStatsTree(capping: Int? = nil) {
        guard isBridgeOpSupported("stats-tree") else { return }
        run(label: "stats-tree") {
            try await self.refreshStatsTreeNow(capping: capping)
        }
    }

    func refreshStatsGraphs(width: Int = 480, scale: Int = 1) {
        guard isBridgeOpSupported("stats-graphs") else { return }
        run(label: "stats-graphs") {
            try await self.refreshStatsGraphsNow(width: width, scale: scale)
        }
    }

    func refreshUploadsNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await bridge.uploads(config: config)
            await MainActor.run {
                self.uploads = payload
                self.lastUploadsRawOutput = raw
                if logOutput {
                    self.appendLog("$ uploads\n\(raw)")
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

    func refreshSharedFilesNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await bridge.sharedFiles(config: config)
            await MainActor.run {
                self.sharedFiles = payload
                self.lastSharedFilesRawOutput = raw
                if logOutput {
                    self.appendLog("$ shared-files\n\(raw)")
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

    func refreshCoreLogNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await bridge.coreLog(config: config)
            await MainActor.run {
                self.coreLogLines = payload.lines
                self.lastCoreLogRawOutput = raw
                if logOutput {
                    self.appendLog("$ log\n\(raw)")
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

    func refreshCoreDebugLogNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await bridge.debugLog(config: config)
            await MainActor.run {
                self.coreDebugLogLines = payload.lines
                self.lastCoreDebugLogRawOutput = raw
                if logOutput {
                    self.appendLog("$ debug-log\n\(raw)")
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

    func refreshCategoriesNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await bridge.categories(config: config)
            await MainActor.run {
                self.categories = payload
                self.lastCategoriesRawOutput = raw
                if logOutput {
                    self.appendLog("$ categories\n\(raw)")
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

    func refreshFriendsNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await bridge.friends(config: config)
            await MainActor.run {
                self.friends = payload
                self.lastFriendsRawOutput = raw
                if logOutput {
                    self.appendLog("$ friends\n\(raw)")
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

    func refreshStatsTreeNow(capping: Int? = nil, logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await bridge.statsTree(capping: capping, config: config)
            await MainActor.run {
                self.statsTree = payload
                self.lastStatsTreeRawOutput = raw
                if logOutput {
                    self.appendLog("$ stats-tree\n\(raw)")
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

    func refreshStatsGraphsNow(width: Int, scale: Int, logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await bridge.statsGraphs(
                width: width,
                scale: scale,
                last: statsGraphsLastTimestamp,
                config: config
            )
            await MainActor.run {
                self.statsGraphs = payload
                self.statsGraphsLastTimestamp = payload.last
                self.lastStatsGraphsRawOutput = raw
                if logOutput {
                    self.appendLog("$ stats-graphs --stats-width \(width) --stats-scale \(scale)\n\(raw)")
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
}
