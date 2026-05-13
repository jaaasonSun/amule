import Foundation

struct IOSBridgeInvocationStub: BridgeInvocation {
    func invokeBridge(
        op: String,
        extraArgs: [String],
        config: AMuleConnectionConfig
    ) async throws -> (envelope: BridgeEnvelope, raw: String) {
        throw AMuleClientError.bridgeFailure("Bridge invocation is not implemented on iOS yet.")
    }
}

typealias IOSPasteboardShareStub = PlatformServiceStubs.Pasteboard
typealias IOSDeepLinkHandlingStub = PlatformServiceStubs.DeepLinks
typealias IOSCredentialStorageStub = PlatformServiceStubs.Credentials
typealias IOSFileExportImportStub = PlatformServiceStubs.Files
typealias IOSLifecycleBackgroundStub = PlatformServiceStubs.Lifecycle
typealias IOSLocalNetworkErrorPresentationStub = PlatformServiceStubs.LocalNetworkErrors
