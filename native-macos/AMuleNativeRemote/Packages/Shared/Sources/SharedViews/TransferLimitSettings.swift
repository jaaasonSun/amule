import Foundation

public enum TransferLimitValidationError: Error, Equatable, Sendable {
    case invalidDownload
    case invalidUpload
}

public struct TransferLimitSettings: Equatable, Sendable {
    public let maxDownload: Int
    public let maxUpload: Int

    public init(maxDownload: Int, maxUpload: Int) {
        self.maxDownload = maxDownload
        self.maxUpload = maxUpload
    }

    public init(downloadText: String, uploadText: String) throws {
        let downloadText = downloadText.trimmingCharacters(in: .whitespacesAndNewlines)
        let uploadText = uploadText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let maxDownload = Int(downloadText), maxDownload >= 0 else {
            throw TransferLimitValidationError.invalidDownload
        }
        guard let maxUpload = Int(uploadText), maxUpload >= 0 else {
            throw TransferLimitValidationError.invalidUpload
        }

        self.maxDownload = maxDownload
        self.maxUpload = maxUpload
    }
}
