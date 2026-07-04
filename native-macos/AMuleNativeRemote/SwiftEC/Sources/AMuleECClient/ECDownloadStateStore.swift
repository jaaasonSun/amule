import Foundation
import AMuleECProtocol

public struct ECDownloadStateStore: Sendable {
    public enum Lifecycle: Equatable, Sendable {
        case active
        case completedRetained
        case sharedOnly
        case malformedOmission
        case tombstoned
        case cleared
    }

    public private(set) var downloads: [ECDownload] = []
    public private(set) var hasBaseline = false

    private var downloadsByECID: [Int: ECDownload] = [:]
    private var lifecycleByECID: [Int: Lifecycle] = [:]
    private var orderedECIDs: [Int] = []
    private var sourceNamesByECID: [Int: [Int: ECDownload.AlternativeName]] = [:]

    public init() {}

    public func lifecycle(forECID ecid: Int) -> Lifecycle? {
        lifecycleByECID[ecid]
    }

    public mutating func acknowledgeClearCompleted(ecids: [Int]) {
        let targets = clearTargets(from: ecids)
        guard !targets.isEmpty else { return }
        for ecid in targets {
            lifecycleByECID[ecid] = .cleared
            downloadsByECID.removeValue(forKey: ecid)
            sourceNamesByECID.removeValue(forKey: ecid)
        }
        publishDownloads()
    }

    public mutating func replaceDownloadSnapshot(_ snapshot: [ECDownload]) {
        replaceDownloadSnapshot(snapshot, sourcePacket: nil)
    }

    public mutating func replaceDownloadSnapshot(_ snapshot: [ECDownload], sourcePacket: ECPacket?) {
        hasBaseline = true
        let previousOrder = orderedECIDs
        let incoming = uniqueDownloads(from: snapshot)
        let liveECIDs = Set(incoming.map(\.ecid))
        let isIncrementalUpdate = sourcePacket?.opcode == 0x22

        var hasCompleteDownloadState: Set<Int> = []
        if let sourcePacket {
            for tag in sourcePacket.tags where tag.name == TagName.partFile || tag.name == TagName.knownFile {
                let ecid = tag.intValue
                if tag.name == TagName.partFile, tag.child(named: TagName.partFileStatus) != nil {
                    hasCompleteDownloadState.insert(ecid)
                }
            }
            for tag in sourcePacket.tags where tag.name == TagName.partFile {
                let ecid = tag.intValue
                guard liveECIDs.contains(ecid) else { continue }
                applySourceNameDeltas(from: tag, ecid: ecid)
            }
            recordMalformedOmissions(from: sourcePacket, parsedECIDs: liveECIDs)
        } else {
            seedDecodedAlternativeNames(from: incoming)
        }

        var nextDownloadsByECID = downloadsByECID
        var nextLifecycleByECID = lifecycleByECID
        var nextOrder = isIncrementalUpdate ? previousOrder : incoming.map(\.ecid)

        for download in incoming {
            let ecid = download.ecid
            if sourcePacket != nil, !hasCompleteDownloadState.contains(ecid), let existing = downloadsByECID[ecid] {
                let merged: ECDownload
                if !download.name.isEmpty, download.name != existing.name {
                    merged = existing.replacingName(download.name)
                } else {
                    merged = existing
                }
                let withAltNames = merged.replacingAlternativeNames(alternativeNames(for: merged))
                nextDownloadsByECID[ecid] = withAltNames
                nextLifecycleByECID[ecid] = lifecycle(for: withAltNames)
                nextOrder.append(ecid)
            } else {
                let merged = download.replacingAlternativeNames(alternativeNames(for: download))
                nextDownloadsByECID[ecid] = merged
                nextLifecycleByECID[ecid] = lifecycle(for: merged)
                nextOrder.append(ecid)
            }
        }

        for ecid in previousOrder where !liveECIDs.contains(ecid) {
            guard let previous = downloadsByECID[ecid] else { continue }
            if lifecycleByECID[ecid] == .cleared {
                nextDownloadsByECID.removeValue(forKey: ecid)
                continue
            }
            if isIncrementalUpdate {
                nextDownloadsByECID.removeValue(forKey: ecid)
                sourceNamesByECID.removeValue(forKey: ecid)
                nextLifecycleByECID[ecid] = .tombstoned
                continue
            }
            if shouldRetainWhenOmitted(previous) {
                nextLifecycleByECID[ecid] = .tombstoned
                nextDownloadsByECID[ecid] = previous
                nextOrder.append(ecid)
            } else {
                nextDownloadsByECID.removeValue(forKey: ecid)
                nextLifecycleByECID[ecid] = .tombstoned
            }
        }

        downloadsByECID = nextDownloadsByECID
        lifecycleByECID = nextLifecycleByECID
        orderedECIDs = uniqueECIDs(nextOrder)
        sourceNamesByECID = sourceNamesByECID.filter { downloadsByECID[$0.key] != nil && lifecycleByECID[$0.key] != .cleared }
        publishDownloads()
    }

    public mutating func applyIncrementalUpdate(_ packet: ECPacket) {
        for tag in packet.tags where tag.name == TagName.partFile {
            applyPartFileDelta(tag)
        }
        publishDownloads()
    }

    public func incrementalUpdateNeedsFullResync(_ packet: ECPacket) -> Bool {
        guard hasBaseline else { return true }
        for tag in packet.tags where tag.name == TagName.partFile || tag.name == TagName.knownFile {
            let ecid = tag.intValue
            guard ecid > 0, downloadsByECID[ecid] == nil else { continue }
            if !tag.hasCompleteFileIdentity {
                return true
            }
        }
        return false
    }

    private mutating func applyPartFileDelta(_ tag: ECTag) {
        let ecid = tag.intValue
        guard ecid > 0 else { return }

        applySourceNameDeltas(from: tag, ecid: ecid)

        guard let existing = downloadsByECID[ecid] else { return }
        guard lifecycleByECID[ecid] != .cleared else { return }
        downloadsByECID[ecid] = existing.replacingAlternativeNames(alternativeNames(for: existing))
    }

    private func clearTargets(from ecids: [Int]) -> Set<Int> {
        let requested = Set(ecids.filter { $0 > 0 })
        if !requested.isEmpty { return requested }
        return Set(downloadsByECID.values.filter(shouldRetainWhenOmitted).map(\.ecid))
    }

    private func lifecycle(for download: ECDownload) -> Lifecycle {
        if isSharedOnly(download) { return .sharedOnly }
        if shouldRetainWhenOmitted(download) { return .completedRetained }
        return .active
    }

    private func shouldRetainWhenOmitted(_ download: ECDownload) -> Bool {
        download.isCompleted || download.statusCode >= 8 || (download.size > 0 && download.done >= download.size)
    }

    private func isSharedOnly(_ download: ECDownload) -> Bool {
        shouldRetainWhenOmitted(download)
            && download.partMet.isEmpty
            && download.sourcesTotal == 0
            && download.sourcesCurrent == 0
            && download.sourcesTransferring == 0
            && download.speed == 0
    }

    private mutating func recordMalformedOmissions(from packet: ECPacket, parsedECIDs: Set<Int>) {
        for tag in packet.tags where tag.name == TagName.partFile {
            let ecid = tag.intValue
            guard !parsedECIDs.contains(ecid), downloadsByECID[ecid] == nil else { continue }
            lifecycleByECID[ecid] = .malformedOmission
        }
    }

    private func uniqueDownloads(from snapshot: [ECDownload]) -> [ECDownload] {
        var order: [Int] = []
        var byECID: [Int: ECDownload] = [:]
        for download in snapshot where download.ecid > 0 {
            if byECID[download.ecid] == nil {
                order.append(download.ecid)
            }
            byECID[download.ecid] = download
        }
        return order.compactMap { byECID[$0] }
    }

    private func uniqueECIDs(_ ecids: [Int]) -> [Int] {
        var seen = Set<Int>()
        var unique: [Int] = []
        for ecid in ecids where seen.insert(ecid).inserted {
            unique.append(ecid)
        }
        return unique
    }

    private mutating func publishDownloads() {
        orderedECIDs = uniqueECIDs(orderedECIDs.filter { downloadsByECID[$0] != nil && lifecycleByECID[$0] != .cleared })
        downloads = orderedECIDs.compactMap { downloadsByECID[$0] }
    }

    private mutating func applySourceNameDeltas(from tag: ECTag, ecid: Int) {
        guard let sourceNames = tag.child(named: TagName.partFileSourceNames) else { return }
        var cached = sourceNamesByECID[ecid, default: [:]]

        for entry in sourceNames.children where entry.name == TagName.partFileSourceNames {
            let id = entry.intValue
            guard id > 0 else { continue }

            let count = entry.child(named: TagName.partFileSourceNameCounts)?.intValue ?? 0
            if count <= 0 {
                cached.removeValue(forKey: id)
                continue
            }

            let name = entry.child(named: TagName.partFileSourceNames)?.stringValue
            if let name, !name.isEmpty {
                cached[id] = ECDownload.AlternativeName(name: name, count: count)
            } else if let previous = cached[id] {
                cached[id] = ECDownload.AlternativeName(name: previous.name, count: count)
            }
        }

        sourceNamesByECID[ecid] = cached
    }

    private func alternativeNames(for download: ECDownload) -> [ECDownload.AlternativeName] {
        Array(sourceNamesByECID[download.ecid, default: [:]]
            .values
            .filter { $0.count > 0 && !$0.name.isEmpty && $0.name != download.name }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.name < rhs.name
            }
            .prefix(12))
    }

    private mutating func seedDecodedAlternativeNames(from snapshot: [ECDownload]) {
        for download in snapshot where !download.alternativeNames.isEmpty {
            var cached = sourceNamesByECID[download.ecid, default: [:]]
            for (offset, alternativeName) in download.alternativeNames.enumerated() where alternativeName.count > 0 {
                if cached.values.contains(where: { $0.name == alternativeName.name }) {
                    continue
                }
                cached[-(offset + 1)] = alternativeName
            }
            sourceNamesByECID[download.ecid] = cached
        }
    }

    fileprivate enum TagName {
        static let partFile: UInt16 = 0x0300
        static let partFileName: UInt16 = 0x0301
        static let partFileSizeFull: UInt16 = 0x0303
        static let partFileStatus: UInt16 = 0x0308
        static let partFileSourceNames: UInt16 = 0x0315
        static let partFileSourceNameCounts: UInt16 = 0x031C
        static let partFileHash: UInt16 = 0x031E
        static let knownFile: UInt16 = 0x0400
        static let knownFileFilename: UInt16 = 0x0408
    }
}

extension ECDownload {
    func replacingAlternativeNames(_ alternativeNames: [AlternativeName]) -> ECDownload {
        ECDownload(
            ecid: ecid,
            hash: hash,
            name: name,
            nameEncodingSuspect: nameEncodingSuspect,
            nameEncodingSuggestion: nameEncodingSuggestion,
            size: size,
            done: done,
            transferred: transferred,
            progress: progress,
            sourcesCurrent: sourcesCurrent,
            sourcesTotal: sourcesTotal,
            sourcesTransferring: sourcesTransferring,
            sourcesA4AF: sourcesA4AF,
            statusCode: statusCode,
            isCompleted: isCompleted,
            status: status,
            speed: speed,
            priority: priority,
            category: category,
            partMet: partMet,
            lastSeenComplete: lastSeenComplete,
            lastReceived: lastReceived,
            activeSeconds: activeSeconds,
            availableParts: availableParts,
            shared: shared,
            alternativeNames: alternativeNames,
            progressColors: progressColors
        )
    }

    func replacingName(_ newName: String) -> ECDownload {
        ECDownload(
            ecid: ecid,
            hash: hash,
            name: newName,
            nameEncodingSuspect: nameEncodingSuspect,
            nameEncodingSuggestion: nameEncodingSuggestion,
            size: size,
            done: done,
            transferred: transferred,
            progress: progress,
            sourcesCurrent: sourcesCurrent,
            sourcesTotal: sourcesTotal,
            sourcesTransferring: sourcesTransferring,
            sourcesA4AF: sourcesA4AF,
            statusCode: statusCode,
            isCompleted: isCompleted,
            status: status,
            speed: speed,
            priority: priority,
            category: category,
            partMet: partMet,
            lastSeenComplete: lastSeenComplete,
            lastReceived: lastReceived,
            activeSeconds: activeSeconds,
            availableParts: availableParts,
            shared: shared,
            alternativeNames: alternativeNames,
            progressColors: progressColors
        )
    }
}

private extension ECTag {
    func child(named name: UInt16) -> ECTag? {
        children.first { $0.name == name }
    }

    var hasCompleteFileIdentity: Bool {
        let name: String?
        let hash: String?
        switch self.name {
        case ECDownloadStateStore.TagName.knownFile:
            name = child(named: ECDownloadStateStore.TagName.knownFileFilename)?.stringValue
                ?? child(named: ECDownloadStateStore.TagName.partFileName)?.stringValue
            hash = child(named: ECDownloadStateStore.TagName.partFileHash)?.hashStringValue ?? hashStringValue
        default:
            name = child(named: ECDownloadStateStore.TagName.partFileName)?.stringValue
            hash = child(named: ECDownloadStateStore.TagName.partFileHash)?.hashStringValue
        }
        guard let name,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              hash?.isEmpty == false,
              child(named: ECDownloadStateStore.TagName.partFileSizeFull) != nil else {
            return false
        }
        return true
    }

    var intValue: Int {
        if case .uint(let value) = value {
            return Int(value)
        }
        return 0
    }

    var stringValue: String? {
        if case .string(let value) = value {
            return value
        }
        return nil
    }

    var hashStringValue: String? {
        if case .hash16(let data) = value {
            return data.map { String(format: "%02x", $0) }.joined()
        }
        return nil
    }
}
