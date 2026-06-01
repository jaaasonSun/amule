import Foundation

public protocol RenameVerifiableDownload {
    var id: String { get }
    var name: String { get }
}

public enum RenameVerification {
    public static func wasApplied<Downloads: Sequence>(downloadID: String, newName: String, downloads: Downloads) -> Bool where Downloads.Element: RenameVerifiableDownload {
        downloads.contains { item in
            item.id == downloadID && item.name == newName
        }
    }
}
