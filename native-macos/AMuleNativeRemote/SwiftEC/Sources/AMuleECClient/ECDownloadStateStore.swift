import Foundation
import AMuleECProtocol

public struct ECDownloadStateStore: Sendable {
    public enum Lifecycle: Equatable, Sendable {
        case active
        case completedRetained
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
    private var progressRLEByECID: [Int: ProgressRLEState] = [:]

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
            progressRLEByECID.removeValue(forKey: ecid)
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
        let partFileTagsByECID = partFileTagsByECID(from: sourcePacket)
        if !isIncrementalUpdate {
            progressRLEByECID = [:]
        }

        var hasCompleteDownloadState: Set<Int> = []
        if let sourcePacket {
            for tag in sourcePacket.tags where tag.name == TagName.partFile {
                let ecid = tag.intValue
                if tag.child(named: TagName.partFileStatus) != nil {
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

        for rawDownload in incoming {
            var download = rawDownload
            let ecid = download.ecid
            if let tag = partFileTagsByECID[ecid],
               let progressColors = progressColors(from: tag, update: download, existing: downloadsByECID[ecid]) {
                download = download.replacingProgressColors(progressColors)
            }
            if sourcePacket != nil, !hasCompleteDownloadState.contains(ecid), let existing = downloadsByECID[ecid] {
                let merged = existing.mergingSparseUpdate(download, tag: partFileTagsByECID[ecid])
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
                progressRLEByECID.removeValue(forKey: ecid)
                continue
            }
            if isIncrementalUpdate {
                nextDownloadsByECID.removeValue(forKey: ecid)
                sourceNamesByECID.removeValue(forKey: ecid)
                progressRLEByECID.removeValue(forKey: ecid)
                nextLifecycleByECID[ecid] = .tombstoned
                continue
            }
            if shouldRetainWhenOmitted(previous) {
                nextLifecycleByECID[ecid] = .tombstoned
                nextDownloadsByECID[ecid] = previous
                nextOrder.append(ecid)
            } else {
                nextDownloadsByECID.removeValue(forKey: ecid)
                progressRLEByECID.removeValue(forKey: ecid)
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
        let updatesByECID = parsedDownloadsByECID(from: packet)
        for tag in packet.tags where tag.name == TagName.partFile {
            applyPartFileDelta(tag, update: updatesByECID[tag.intValue])
        }
        publishDownloads()
    }

    public func incrementalUpdateNeedsFullResync(_ packet: ECPacket) -> Bool {
        guard hasBaseline else { return true }
        for tag in packet.tags where tag.name == TagName.partFile {
            let ecid = tag.intValue
            guard ecid > 0, downloadsByECID[ecid] == nil else { continue }
            if !tag.hasCompleteFileIdentity {
                return true
            }
        }
        return false
    }

    private mutating func applyPartFileDelta(_ tag: ECTag, update: ECDownload?) {
        let ecid = tag.intValue
        guard ecid > 0 else { return }

        applySourceNameDeltas(from: tag, ecid: ecid)

        guard let existing = downloadsByECID[ecid] else { return }
        guard lifecycleByECID[ecid] != .cleared else { return }
        var update = update
        if let parsedUpdate = update,
           let progressColors = progressColors(from: tag, update: parsedUpdate, existing: existing) {
            update = parsedUpdate.replacingProgressColors(progressColors)
        }
        let merged = update.map { existing.mergingSparseUpdate($0, tag: tag) } ?? existing
        let withAltNames = merged.replacingAlternativeNames(alternativeNames(for: merged))
        downloadsByECID[ecid] = withAltNames
        lifecycleByECID[ecid] = lifecycle(for: withAltNames)
    }

    private func clearTargets(from ecids: [Int]) -> Set<Int> {
        let requested = Set(ecids.filter { $0 > 0 })
        if !requested.isEmpty { return requested }
        return Set(downloadsByECID.values.filter(shouldRetainWhenOmitted).map(\.ecid))
    }

    private func lifecycle(for download: ECDownload) -> Lifecycle {
        if shouldRetainWhenOmitted(download) { return .completedRetained }
        return .active
    }

    private func shouldRetainWhenOmitted(_ download: ECDownload) -> Bool {
        download.isCompleted || download.statusCode == 9
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

    private func partFileTagsByECID(from packet: ECPacket?) -> [Int: ECTag] {
        guard let packet else { return [:] }
        var tags: [Int: ECTag] = [:]
        for tag in packet.tags where tag.name == TagName.partFile {
            tags[tag.intValue] = tag
        }
        return tags
    }

    private func parsedDownloadsByECID(from packet: ECPacket) -> [Int: ECDownload] {
        guard let parsed = try? ECResponseParser.parseDownloads(packet) else { return [:] }
        var downloads: [Int: ECDownload] = [:]
        for download in parsed where download.ecid > 0 {
            downloads[download.ecid] = download
        }
        return downloads
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
        progressRLEByECID = progressRLEByECID.filter { downloadsByECID[$0.key] != nil && lifecycleByECID[$0.key] != .cleared }
        downloads = orderedECIDs.compactMap { downloadsByECID[$0] }
    }

    private mutating func progressColors(from tag: ECTag, update: ECDownload, existing: ECDownload?) -> [UInt32]? {
        let hasRLEProgress = tag.hasAnyChild(named: [
            TagName.partFileGapStatus,
            TagName.partFilePartStatus,
            TagName.partFileRequestStatus,
        ])
        let shouldRepaintExistingProgress = hasRLEProgress ||
            tag.child(named: TagName.partFileStopped) != nil ||
            tag.child(named: TagName.partFileStatus) != nil ||
            tag.child(named: TagName.partFileHashedPartCount) != nil
        guard shouldRepaintExistingProgress else { return nil }

        var state = progressRLEByECID[tag.intValue, default: ProgressRLEState()]
        if let gapData = tag.child(named: TagName.partFileGapStatus)?.customData {
            state.applyGaps(gapData)
        }
        if let partData = tag.child(named: TagName.partFilePartStatus)?.customData {
            state.applyParts(partData)
        }
        if let requestData = tag.child(named: TagName.partFileRequestStatus)?.customData {
            state.applyRequests(requestData)
        }
        progressRLEByECID[tag.intValue] = state

        if update.statusCode == 8 || update.statusCode == 9 || update.hashingProgressParts > 0 {
            return update.progressColors.isEmpty ? nil : update.progressColors
        }

        guard hasRLEProgress || existing?.progressColors.isEmpty == false else { return nil }
        return Self.buildProgressSegments(
            gaps: state.gaps,
            partInfo: state.partInfo,
            requests: state.requests,
            fileSize: update.size > 0 ? update.size : (existing?.size ?? 0),
            statusCode: update.statusCode,
            isStopped: update.isStopped,
            explicitProgressState: hasRLEProgress
        )
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

    private static func buildProgressSegments(
        gaps: [UInt64],
        partInfo: [UInt8],
        requests: [UInt64],
        fileSize: UInt64,
        statusCode: Int,
        isStopped: Bool,
        explicitProgressState: Bool
    ) -> [UInt32] {
        let segmentCount = 64
        let progressColor = packedColor(r: 0, g: 224, b: 0)
        let downloadedColor = packedColor(r: 104, g: 104, b: 104)
        let requestedColor = isStopped ? blendColor(r: 255, g: 208, b: 0, percentage: 50) : packedColor(r: 255, g: 208, b: 0)
        if statusCode == 8 || statusCode == 9 {
            return Array(repeating: progressColor, count: segmentCount)
        }

        guard explicitProgressState || !gaps.isEmpty || !partInfo.isEmpty || !requests.isEmpty else { return [] }

        var colorLine = Array(repeating: downloadedColor, count: segmentCount)
        guard fileSize > 0 else { return colorLine }

        var gapRanges: [ColoredProgressRange] = []
        for pairIndex in stride(from: 0, to: gaps.count - (gaps.count % 2), by: 2) {
            let gapStart = gaps[pairIndex]
            let gapEnd = gaps[pairIndex + 1]
            guard gapEnd > gapStart else { continue }

            let startPart = Int(gapStart / partSize)
            let endPart = Int((gapEnd / partSize) + 1)
            guard endPart > startPart else { continue }

            for part in startPart..<endPart {
                var color = packedColor(r: 255, g: 0, b: 0)
                if part < partInfo.count, partInfo[part] > 0 {
                    let green = max(0, 210 - (22 * (Int(partInfo[part]) - 1)))
                    color = packedColor(r: 0, g: green, b: 255)
                }
                if isStopped {
                    color = blendPackedColor(color, percentage: 50)
                }

                let partStart = UInt64(part) * partSize
                let partEnd = UInt64(part + 1) * partSize
                let fillStart = part == startPart ? gapStart : partStart
                let fillEnd = part == endPart - 1 ? gapEnd : partEnd
                guard fillEnd > fillStart else { continue }

                if let last = gapRanges.last, last.end == fillStart, last.color == color {
                    gapRanges[gapRanges.count - 1].end = fillEnd
                } else {
                    gapRanges.append(ColoredProgressRange(start: fillStart, end: fillEnd, color: color))
                }
            }
        }

        var requestRanges: [ColoredProgressRange] = []
        for pairIndex in stride(from: 0, to: requests.count - (requests.count % 2), by: 2) {
            let requestStart = requests[pairIndex]
            let requestEnd = requests[pairIndex + 1]
            guard requestEnd > requestStart else { continue }
            requestRanges.append(ColoredProgressRange(start: requestStart, end: requestEnd, color: requestedColor))
        }

        if fileSize < UInt64(segmentCount) {
            if !requestRanges.isEmpty {
                return Array(repeating: requestedColor, count: segmentCount)
            }
            if let firstGap = gapRanges.first {
                return Array(repeating: firstGap.color, count: segmentCount)
            }
            return colorLine
        }

        let factor = fileSize / UInt64(segmentCount)
        guard factor > 0 else { return colorLine }

        func paint(_ ranges: [ColoredProgressRange], on colorLine: inout [UInt32]) {
            for range in ranges {
                var start = Int(range.start / factor)
                var end = Int(range.end / factor)
                guard start < segmentCount else { continue }
                start = max(0, start)
                end = min(segmentCount, end)
                if end <= start {
                    end = min(segmentCount, start + 1)
                }
                guard end > start else { continue }
                for position in start..<end {
                    colorLine[position] = range.color
                }
            }
        }

        paint(gapRanges, on: &colorLine)
        paint(requestRanges, on: &colorLine)
        return colorLine
    }

    private static let partSize: UInt64 = 9_728_000

    private static func packedColor(r: Int, g: Int, b: Int) -> UInt32 {
        (UInt32(b & 0xff) << 16) | (UInt32(g & 0xff) << 8) | UInt32(r & 0xff)
    }

    private static func blendPackedColor(_ color: UInt32, percentage: Int) -> UInt32 {
        let red = Int(color & 0xff)
        let green = Int((color >> 8) & 0xff)
        let blue = Int((color >> 16) & 0xff)
        return blendColor(r: red, g: green, b: blue, percentage: percentage)
    }

    private static func blendColor(r: Int, g: Int, b: Int, percentage: Int) -> UInt32 {
        packedColor(
            r: min(255, (r * percentage) / 100),
            g: min(255, (g * percentage) / 100),
            b: min(255, (b * percentage) / 100)
        )
    }

    fileprivate enum TagName {
        static let partFile: UInt16 = 0x0300
        static let partFileName: UInt16 = 0x0301
        static let partFilePartMetID: UInt16 = 0x0302
        static let partFileSizeFull: UInt16 = 0x0303
        static let partFileSizeTransfer: UInt16 = 0x0304
        static let partFileSizeDone: UInt16 = 0x0306
        static let partFileSpeed: UInt16 = 0x0307
        static let partFileStatus: UInt16 = 0x0308
        static let partFilePriority: UInt16 = 0x0309
        static let partFileSourceCount: UInt16 = 0x030A
        static let partFileSourceCountA4AF: UInt16 = 0x030B
        static let partFileSourceCountNotCurrent: UInt16 = 0x030C
        static let partFileSourceCountTransfer: UInt16 = 0x030D
        static let partFileCategory: UInt16 = 0x030F
        static let partFileLastReceived: UInt16 = 0x0310
        static let partFileLastSeenComplete: UInt16 = 0x0311
        static let partFileSourceNames: UInt16 = 0x0315
        static let partFileStopped: UInt16 = 0x0317
        static let partFileSourceNameCounts: UInt16 = 0x031C
        static let partFileAvailableParts: UInt16 = 0x031D
        static let partFileHash: UInt16 = 0x031E
        static let partFileShared: UInt16 = 0x031F
        static let partFileGapStatus: UInt16 = 0x0313
        static let partFilePartStatus: UInt16 = 0x0312
        static let partFileRequestStatus: UInt16 = 0x0314
        static let partFileHashedPartCount: UInt16 = 0x0320
    }

    private struct ProgressRLEState: Sendable {
        var partInfo: [UInt8] = []
        var gaps: [UInt64] = []
        var requests: [UInt64] = []

        private var partBytes: [UInt8] = []
        private var gapBytes: [UInt8] = []
        private var requestBytes: [UInt8] = []

        mutating func applyParts(_ data: Data) {
            partBytes = Self.applyRLE(data, to: partBytes)
            partInfo = partBytes
        }

        mutating func applyGaps(_ data: Data) {
            gapBytes = Self.applyRLE(data, to: gapBytes)
            gaps = Self.uint64Values(from: gapBytes)
        }

        mutating func applyRequests(_ data: Data) {
            requestBytes = Self.applyRLE(data, to: requestBytes)
            requests = Self.uint64Values(from: requestBytes)
        }

        private static func applyRLE(_ data: Data, to previous: [UInt8]) -> [UInt8] {
            let delta = expandedRLEBytes(data)
            var current = previous
            if current.count < delta.count {
                current.append(contentsOf: repeatElement(0, count: delta.count - current.count))
            } else if current.count > delta.count {
                current = Array(current.prefix(delta.count))
            }
            for index in delta.indices {
                current[index] ^= delta[index]
            }
            return current
        }

        private static func expandedRLEBytes(_ data: Data) -> [UInt8] {
            let bytes = [UInt8](data)
            var decoded: [UInt8] = []
            var index = 0
            while index < bytes.count {
                if index < bytes.count - 2, bytes[index + 1] == bytes[index] {
                    decoded.append(contentsOf: repeatElement(bytes[index], count: Int(bytes[index + 2])))
                    index += 3
                } else {
                    decoded.append(bytes[index])
                    index += 1
                }
            }
            return decoded
        }

        private static func uint64Values(from bytes: [UInt8]) -> [UInt64] {
            guard !bytes.isEmpty, bytes.count % 8 == 0 else { return [] }
            let count = bytes.count / 8
            return (0..<count).map { index -> UInt64 in
                var value: UInt64 = 0
                for byteIndex in stride(from: 7, through: 0, by: -1) {
                    value <<= 8
                    value |= UInt64(bytes[index + byteIndex * count])
                }
                return value
            }
        }
    }

    private struct ColoredProgressRange {
        let start: UInt64
        var end: UInt64
        let color: UInt32
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
            progressColors: progressColors,
            isStopped: isStopped,
            hashingProgressParts: hashingProgressParts,
            displayProgress: displayProgress
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
            progressColors: progressColors,
            isStopped: isStopped,
            hashingProgressParts: hashingProgressParts,
            displayProgress: displayProgress
        )
    }

    func replacingProgressColors(_ colors: [UInt32]) -> ECDownload {
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
            progressColors: colors,
            isStopped: isStopped,
            hashingProgressParts: hashingProgressParts,
            displayProgress: displayProgress
        )
    }

    func mergingSparseUpdate(_ update: ECDownload, tag: ECTag?) -> ECDownload {
        let hasName = tag?.child(named: ECDownloadStateStore.TagName.partFileName) != nil
        let nextName = hasName && !update.name.isEmpty ? update.name : name
        let hasProgressTags = tag?.hasAnyChild(named: [
            ECDownloadStateStore.TagName.partFileGapStatus,
            ECDownloadStateStore.TagName.partFilePartStatus,
            ECDownloadStateStore.TagName.partFileRequestStatus,
            ECDownloadStateStore.TagName.partFileHashedPartCount,
            ECDownloadStateStore.TagName.partFileStopped,
            ECDownloadStateStore.TagName.partFileStatus,
        ]) == true
        let hasSize = tag?.child(named: ECDownloadStateStore.TagName.partFileSizeFull) != nil
        let hasDone = tag?.child(named: ECDownloadStateStore.TagName.partFileSizeDone) != nil
        let hasTransferred = tag?.child(named: ECDownloadStateStore.TagName.partFileSizeTransfer) != nil
        let hasSpeed = tag?.child(named: ECDownloadStateStore.TagName.partFileSpeed) != nil
        let hasStatusCode = tag?.child(named: ECDownloadStateStore.TagName.partFileStatus) != nil
        let hasPriority = tag?.child(named: ECDownloadStateStore.TagName.partFilePriority) != nil
        let hasSourceTotal = tag?.child(named: ECDownloadStateStore.TagName.partFileSourceCount) != nil
        let hasSourceA4AF = tag?.child(named: ECDownloadStateStore.TagName.partFileSourceCountA4AF) != nil
        let hasSourceNotCurrent = tag?.child(named: ECDownloadStateStore.TagName.partFileSourceCountNotCurrent) != nil
        let hasSourceTransfer = tag?.child(named: ECDownloadStateStore.TagName.partFileSourceCountTransfer) != nil
        let hasCategory = tag?.child(named: ECDownloadStateStore.TagName.partFileCategory) != nil
        let hasLastReceived = tag?.child(named: ECDownloadStateStore.TagName.partFileLastReceived) != nil
        let hasLastSeenComplete = tag?.child(named: ECDownloadStateStore.TagName.partFileLastSeenComplete) != nil
        let hasPartMet = tag?.child(named: ECDownloadStateStore.TagName.partFilePartMetID) != nil
        let hasStopped = tag?.child(named: ECDownloadStateStore.TagName.partFileStopped) != nil
        let hasHashingProgress = tag?.child(named: ECDownloadStateStore.TagName.partFileHashedPartCount) != nil
        let hasAvailableParts = tag?.child(named: ECDownloadStateStore.TagName.partFileAvailableParts) != nil
        let hasShared = tag?.child(named: ECDownloadStateStore.TagName.partFileShared) != nil
        let nextSize = hasSize ? update.size : size
        let nextDone = hasDone ? update.done : done
        let nextTransferred = hasTransferred ? update.transferred : transferred
        let nextProgress = nextSize > 0 ? 100.0 * Double(nextDone) / Double(nextSize) : 0
        let previousNotCurrent = max(0, sourcesTotal - sourcesCurrent)
        let nextSourcesTotal = hasSourceTotal ? update.sourcesTotal : sourcesTotal
        let nextNotCurrent = hasSourceNotCurrent ? (tag?.child(named: ECDownloadStateStore.TagName.partFileSourceCountNotCurrent)?.intValue ?? 0) : previousNotCurrent
        let nextSourcesCurrent = max(0, nextSourcesTotal - nextNotCurrent)
        let nextSourcesTransferring = hasSourceTransfer ? update.sourcesTransferring : sourcesTransferring
        let nextStatusCode = hasStatusCode ? update.statusCode : statusCode
        let nextIsCompleted = hasStatusCode ? update.isCompleted : isCompleted
        let nextIsStopped = hasStopped ? update.isStopped : isStopped
        let nextStatus = (hasStatusCode || hasStopped || hasSourceTransfer)
            ? Self.statusText(statusCode: nextStatusCode, sourcesTransferring: nextSourcesTransferring, isStopped: nextIsStopped)
            : status
        let nextHashingProgressParts = hasHashingProgress ? update.hashingProgressParts : hashingProgressParts
        let nextDisplayProgress = hasHashingProgress
            ? Self.progressPercent(done: UInt64(nextHashingProgressParts) * 9_728_000, size: nextSize, isCompleted: nextStatusCode == 9)
            : displayProgress

        return ECDownload(
            ecid: ecid,
            hash: hash,
            name: nextName,
            nameEncodingSuspect: nameEncodingSuspect,
            nameEncodingSuggestion: nameEncodingSuggestion,
            size: nextSize,
            done: nextDone,
            transferred: nextTransferred,
            progress: nextProgress,
            sourcesCurrent: nextSourcesCurrent,
            sourcesTotal: nextSourcesTotal,
            sourcesTransferring: nextSourcesTransferring,
            sourcesA4AF: hasSourceA4AF ? update.sourcesA4AF : sourcesA4AF,
            statusCode: nextStatusCode,
            isCompleted: nextIsCompleted,
            status: nextStatus,
            speed: hasSpeed ? update.speed : speed,
            priority: hasPriority ? update.priority : priority,
            category: hasCategory ? update.category : category,
            partMet: hasPartMet ? update.partMet : partMet,
            lastSeenComplete: hasLastSeenComplete ? update.lastSeenComplete : lastSeenComplete,
            lastReceived: hasLastReceived ? update.lastReceived : lastReceived,
            activeSeconds: activeSeconds,
            availableParts: hasAvailableParts ? update.availableParts : availableParts,
            shared: hasShared ? update.shared : shared,
            alternativeNames: alternativeNames,
            progressColors: hasProgressTags && !update.progressColors.isEmpty ? update.progressColors : progressColors,
            isStopped: nextIsStopped,
            hashingProgressParts: nextHashingProgressParts,
            displayProgress: nextDisplayProgress
        )
    }

    private static func progressPercent(done: UInt64, size: UInt64, isCompleted: Bool) -> Double {
        guard size > 0 else { return 0 }
        if isCompleted { return 100 }
        let percent = 100.0 * Double(done) / Double(size)
        return percent > 99.9 ? 99.9 : percent
    }

    private static func statusText(statusCode: Int, sourcesTransferring: Int, isStopped: Bool) -> String {
        if isStopped && statusCode != 9 { return "Stopped" }
        switch statusCode {
        case 0, 1:
            return sourcesTransferring > 0 ? "Downloading" : "Waiting"
        case 2, 3: return "Hashing"
        case 4: return "Erroneous"
        case 5: return "Insufficient disk space"
        case 6: return "Unknown"
        case 7: return "Paused"
        case 8: return "Completing"
        case 9: return "Complete"
        case 10: return "Allocating"
        default: return String(statusCode)
        }
    }
}

private extension ECTag {
    func child(named name: UInt16) -> ECTag? {
        children.first { $0.name == name }
    }

    func hasAnyChild(named names: [UInt16]) -> Bool {
        children.contains { names.contains($0.name) }
    }

    var hasCompleteFileIdentity: Bool {
        let name = child(named: ECDownloadStateStore.TagName.partFileName)?.stringValue
        let hash = child(named: ECDownloadStateStore.TagName.partFileHash)?.hashStringValue
        guard let name,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              hash?.isEmpty == false,
              child(named: ECDownloadStateStore.TagName.partFileSizeFull) != nil,
              child(named: ECDownloadStateStore.TagName.partFileStatus) != nil else {
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

    var customData: Data? {
        if case .custom(let data) = value {
            return data
        }
        return nil
    }
}
