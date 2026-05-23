import Foundation
import AMuleECProtocol

public struct ECDownloadStateStore: Sendable {
    public private(set) var downloads: [ECDownload] = []

    private var downloadsByECID: [Int: ECDownload] = [:]
    private var sourceNamesByECID: [Int: [Int: ECDownload.AlternativeName]] = [:]

    public init() {}

    public mutating func replaceDownloadSnapshot(_ snapshot: [ECDownload]) {
        replaceDownloadSnapshot(snapshot, sourcePacket: nil)
    }

    public mutating func replaceDownloadSnapshot(_ snapshot: [ECDownload], sourcePacket: ECPacket?) {
        let liveECIDs = Set(snapshot.map(\.ecid))

        if let sourcePacket {
            for tag in sourcePacket.tags where tag.name == TagName.partFile {
                let ecid = tag.intValue
                guard liveECIDs.contains(ecid) else { continue }
                applySourceNameDeltas(from: tag, ecid: ecid)
            }
        } else {
            seedDecodedAlternativeNames(from: snapshot)
        }

        sourceNamesByECID = sourceNamesByECID.filter { liveECIDs.contains($0.key) }

        downloadsByECID = Dictionary(uniqueKeysWithValues: snapshot.map { download in
            let merged = download.replacingAlternativeNames(alternativeNames(for: download))
            return (download.ecid, merged)
        })
        downloads = snapshot.compactMap { downloadsByECID[$0.ecid] }
    }

    public mutating func applyIncrementalUpdate(_ packet: ECPacket) {
        for tag in packet.tags where tag.name == TagName.partFile {
            applyPartFileDelta(tag)
        }
        downloads = downloads.map { downloadsByECID[$0.ecid] ?? $0 }
    }

    private mutating func applyPartFileDelta(_ tag: ECTag) {
        let ecid = tag.intValue
        guard ecid > 0 else { return }

        applySourceNameDeltas(from: tag, ecid: ecid)

        guard let existing = downloadsByECID[ecid] else { return }
        downloadsByECID[ecid] = existing.replacingAlternativeNames(alternativeNames(for: existing))
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

    private enum TagName {
        static let partFile: UInt16 = 0x0300
        static let partFileSourceNames: UInt16 = 0x0315
        static let partFileSourceNameCounts: UInt16 = 0x031C
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
}

private extension ECTag {
    func child(named name: UInt16) -> ECTag? {
        children.first { $0.name == name }
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
}
