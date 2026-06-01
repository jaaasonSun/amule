import Foundation
import SharedUI
import SharedCore

public typealias DownloadAlternativeName = SharedCore.DownloadAlternativeName
public typealias SearchResult = SharedCore.SearchResult
public typealias DownloadItem = SharedCore.DownloadItem
public typealias ServerItem = SharedCore.ServerItem

public enum SourceDownloadState: Int {
    case connecting          = 1
    case onQueue             = 2
    case downloading         = 4
    case tooManyConnections  = 5
}

extension DownloadItem: @retroactive RenameVerifiableDownload {}
extension DownloadItem: @retroactive DownloadClassifiable {}
