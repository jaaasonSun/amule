import Foundation

@available(macOS 13.0, iOS 15.0, *)
public enum RenameVerification {
    public static func wasApplied(downloadID: String, newName: String, downloads: [DownloadItem]) -> Bool {
        downloads.contains { item in
            item.id == downloadID && item.name == newName
        }
    }
}
