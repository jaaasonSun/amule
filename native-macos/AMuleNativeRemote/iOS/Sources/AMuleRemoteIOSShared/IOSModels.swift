import Foundation
import SharedViews
import SharedModels
import SharedServices

public typealias DownloadAlternativeName = SharedModels.DownloadAlternativeName
public typealias SearchResult = SharedModels.SearchResult
public typealias DownloadItem = SharedModels.DownloadItem
public typealias ServerItem = SharedModels.ServerItem

public enum SourceDownloadState: Int {
    case connecting          = 1
    case onQueue             = 2
    case downloading         = 4
    case tooManyConnections  = 5
}

extension DownloadItem: @retroactive RenameVerifiableDownload {}
extension DownloadItem: @retroactive DownloadClassifiable {}
