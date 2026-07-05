import Foundation

extension AppModel {
    func setSharedFilePriority(hash: String, priority: Int) {
        guard isBridgeOpSupported("shared-file-priority") else { return }
        run(label: "shared-file-priority") {
            let (_, raw) = try await self.bridge.sharedFilePriority(hash: hash, priority: priority, config: self.config)
            await MainActor.run {
                self.appendLog("$ shared-file-priority \(hash) \(priority)\n\(raw)")
            }
            if self.isBridgeOpSupported("shared-files") {
                try await self.refreshSharedFilesNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func setSharedFileCommentRating(hash: String, comment: String, rating: Int) {
        guard isBridgeOpSupported("shared-file-comment-rating") else { return }
        run(label: "shared-file-comment-rating") {
            let (_, raw) = try await self.bridge.sharedFileCommentRating(
                hash: hash,
                comment: comment,
                rating: rating,
                config: self.config
            )
            await MainActor.run {
                self.appendLog("$ shared-file-comment-rating \(hash)\n\(raw)")
            }
            if self.isBridgeOpSupported("shared-files") {
                try await self.refreshSharedFilesNow(logOutput: false, suppressErrors: true)
            }
        }
    }
}
