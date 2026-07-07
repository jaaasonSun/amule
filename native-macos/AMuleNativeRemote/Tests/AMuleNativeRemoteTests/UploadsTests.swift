import XCTest
import AMuleECBridgeAdapter
import AMuleECClient
import SharedModels

@testable import AMuleNativeRemote

final class UploadsTests: XCTestCase {
    func testDecodeUploadsEnvelope() throws {
        let json = #"{"ok":true,"uploads":[{"client_id":1,"client_name":"Alice","user_ip":"10.0.0.2","user_port":4662,"server_ip":"1.2.3.4","server_port":4242,"server_name":"Server A","speed_up":1234,"xfer_up":2048,"xfer_down":4096,"upload_file":null},{"client_id":2,"client_name":"Bob","user_ip":"10.0.0.3","user_port":4662,"server_ip":"1.2.3.4","server_port":4242,"server_name":"Server A","speed_up":0,"xfer_up":0,"xfer_down":1,"upload_file":123}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        XCTAssertTrue(decoded.ok)

        let uploads = try XCTUnwrap(decoded.uploads)
        XCTAssertEqual(uploads.count, 2)

        XCTAssertEqual(uploads[0].clientID, 1)
        XCTAssertEqual(uploads[0].clientName, "Alice")
        XCTAssertEqual(uploads[0].userIP, "10.0.0.2")
        XCTAssertEqual(uploads[0].userPort, 4662)
        XCTAssertEqual(uploads[0].serverName, "Server A")
        XCTAssertEqual(uploads[0].speedUp, 1234)
        XCTAssertEqual(uploads[0].xferUp, 2048)
        XCTAssertEqual(uploads[0].xferDown, 4096)
        XCTAssertNil(uploads[0].uploadFile)

        XCTAssertEqual(uploads[1].clientID, 2)
        XCTAssertEqual(uploads[1].clientName, "Bob")
        XCTAssertEqual(uploads[1].uploadFile, 123)
    }

    @MainActor
    func testRefreshUploadsIsGatedAndDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("uploads"))

        model.refreshUploads()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }
}

final class ConnectionStateTests: XCTestCase {
    @MainActor
    func testRefreshConnectionStateIsGatedAndDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("connection-state"))

        model.refreshConnectionState()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testRefreshConnectionStateCallsBridgeAndUpdatesModel() async {
        let bridge = FakeBridgeAdapter()
        let model = AppModel(bridge: bridge)
        model.bridgeOps = ["connection-state"]

        model.refreshConnectionState()
        for _ in 0..<100 where model.isBusy || !bridge.invokedOperations.contains("connection-state") {
            await Task.yield()
        }

        XCTAssertEqual(model.lastError, "")
        XCTAssertNotNil(model.connectionState)
        XCTAssertFalse(model.isBusy)
    }
}

final class SharedFilesTests: XCTestCase {
    func testDecodeSharedFilesEnvelope() throws {
        let json = #"{"ok":true,"shared_files":[{"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"File A","path":"/tmp/file-a.bin","size":1234,"ed2k_link":"ed2k://|file|file-a.bin|1234|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/","priority":10,"requests":1,"requests_all":5,"accepts":1,"accepts_all":4,"xferred":100,"xferred_all":200,"comment":"hello","rating":4,"aich_master_hash":"","on_queue":0,"complete_sources":0,"complete_sources_low":0,"complete_sources_high":0},{"hash":"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB","name":"File B","path":"/tmp/file-b.bin","size":42,"ed2k_link":"","priority":5,"requests":0,"requests_all":0,"accepts":0,"accepts_all":0,"xferred":0,"xferred_all":0,"aich_master_hash":"","on_queue":0,"complete_sources":0,"complete_sources_low":0,"complete_sources_high":0}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        XCTAssertTrue(decoded.ok)

        let shared = try XCTUnwrap(decoded.sharedFiles)
        XCTAssertEqual(shared.count, 2)
        XCTAssertEqual(shared[0].name, "File A")
        XCTAssertEqual(shared[0].requestsAll, 5)
        XCTAssertEqual(shared[0].comment, "hello")
        XCTAssertEqual(shared[0].rating, 4)

        XCTAssertEqual(shared[1].name, "File B")
        XCTAssertNil(shared[1].comment)
        XCTAssertNil(shared[1].rating)
    }

    @MainActor
    func testSharedFilesGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("shared-files"))
        model.refreshSharedFiles()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testSharedFilesReloadGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("shared-files-reload"))
        model.reloadSharedFiles()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }
}

final class CoreLogTests: XCTestCase {
    func testDecodeCoreLogEnvelope() throws {
        let json = #"{"ok":true,"log":{"kind":"debug","lines":["line one","line two"]}}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.log?.kind, "debug")
        XCTAssertEqual(decoded.log?.lines, ["line one", "line two"])
    }

    @MainActor
    func testCoreLogGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("log"))
        model.refreshCoreLog()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testCoreDebugLogGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("debug-log"))
        model.refreshCoreDebugLog()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testLastLogEntryGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("last-log-entry"))
        model.refreshLastLogEntry()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testResetDebugLogGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("reset-debug-log"))
        model.resetDebugLog()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }
}


final class KadTests: XCTestCase {
    @MainActor
    func testKadStartGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("kad-start"))
        model.startKad()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testKadStopGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("kad-stop"))
        model.stopKad()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testKadBootstrapInvalidInputSetsSafeError() {
        let model = AppModel()
        model.bridgeOps = ["kad-bootstrap"]

        model.bootstrapKad(ip: "not.an.ip", port: "4661")
        XCTAssertFalse(model.lastError.isEmpty)
        XCTAssertFalse(model.isBusy)

        model.lastError = ""
        model.bootstrapKad(ip: "1.2.3.4", port: "99999")
        XCTAssertFalse(model.lastError.isEmpty)
        XCTAssertFalse(model.isBusy)
    }
}

final class PreferencesTests: XCTestCase {
    func testDecodeConnectionPrefsEnvelope() throws {
        let json = #"{"ok":true,"prefs_connection":{"max_dl":512,"max_ul":64,"tcp_port":4662,"udp_port":4672,"udp_enabled":true,"ed2k_enabled":true,"kad_enabled":false,"incoming_dir":"/incoming","temp_dir":"/temp","shared_dirs":["/shared"],"server_update_url":"https://example.test/server.met","auto_update_servers":true,"dead_server_retries":3,"new_files_paused":true,"auto_download_priority":true,"preview_priority":false,"auto_upload_priority":true,"save_sources":true,"extract_metadata":false,"allocate_full_file_size":true,"check_free_space":true,"min_free_disk_space_mb":512,"create_sparse_files":true,"ip_filter_level":127,"filter_clients":true,"filter_servers":true,"webserver_enabled":true,"webserver_port":4711,"statistics_supported":false}}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.prefsConnection?.maxDownload, 512)
        XCTAssertEqual(decoded.prefsConnection?.maxUpload, 64)
        XCTAssertEqual(decoded.prefsConnection?.tcpPort, 4662)
        XCTAssertEqual(decoded.prefsConnection?.udpPort, 4672)
        XCTAssertEqual(decoded.prefsConnection?.incomingDirectory, "/incoming")
        XCTAssertEqual(decoded.prefsConnection?.sharedDirectories, ["/shared"])
        XCTAssertEqual(decoded.prefsConnection?.serverUpdateURL, "https://example.test/server.met")
        XCTAssertEqual(decoded.prefsConnection?.newFilesPaused, true)
        XCTAssertEqual(decoded.prefsConnection?.autoDownloadPriority, true)
        XCTAssertEqual(decoded.prefsConnection?.previewPriority, false)
        XCTAssertEqual(decoded.prefsConnection?.autoUploadPriority, true)
        XCTAssertEqual(decoded.prefsConnection?.saveSources, true)
        XCTAssertEqual(decoded.prefsConnection?.extractMetadata, false)
        XCTAssertEqual(decoded.prefsConnection?.allocateFullFileSize, true)
        XCTAssertEqual(decoded.prefsConnection?.checkFreeSpace, true)
        XCTAssertEqual(decoded.prefsConnection?.minFreeDiskSpaceMB, 512)
        XCTAssertEqual(decoded.prefsConnection?.createSparseFiles, true)
        XCTAssertEqual(decoded.prefsConnection?.ipFilterLevel, 127)
        XCTAssertEqual(decoded.prefsConnection?.webServerPort, 4711)
        XCTAssertEqual(decoded.prefsConnection?.statisticsSupported, false)
    }

    @MainActor
    func testRefreshConnectionPrefsGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("prefs-connection-get"))
        model.refreshConnectionPrefs()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testSetConnectionPrefsGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("prefs-connection-set"))
        model.setConnectionSpeedLimits(maxDL: "128", maxUL: "32")
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testSetConnectionPrefsRejectsInvalidInput() {
        let model = AppModel()
        model.bridgeOps = ["prefs-connection-set"]

        model.setConnectionSpeedLimits(maxDL: "-1", maxUL: "32")
        XCTAssertFalse(model.lastError.isEmpty)
        XCTAssertFalse(model.isBusy)

        model.lastError = ""
        model.setConnectionSpeedLimits(maxDL: "256", maxUL: "not-a-number")
        XCTAssertFalse(model.lastError.isEmpty)
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testSetDirectoriesPrefsRejectsEmptyIncomingDirectory() {
        let model = AppModel()
        model.bridgeOps = ["prefs-connection-set"]

        model.setDirectoriesPrefs(incoming: "", temp: "/temp", sharedDirectories: "/shared")

        XCTAssertEqual(model.lastError, "Incoming directory is required.")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testSetDirectoriesPrefsWritesOnlyDirectoriesGroup() async {
        let bridge = FakeBridgeAdapter()
        let model = AppModel(bridge: bridge)
        model.bridgeOps = ["prefs-connection-get", "prefs-connection-set"]
        model.shareHiddenFiles = true

        model.setDirectoriesPrefs(incoming: "/incoming", temp: "/temp", sharedDirectories: "/shared/a\n/shared/b")
        await waitForPreferenceWrite(in: model, bridge: bridge)

        XCTAssertEqual(bridge.lastPrefsGroup, .directories)
        XCTAssertEqual(bridge.lastPrefsSet?.incomingDirectory, "/incoming")
        XCTAssertEqual(bridge.lastPrefsSet?.tempDirectory, "/temp")
        XCTAssertEqual(bridge.lastPrefsSet?.sharedDirectories, ["/shared/a", "/shared/b"])
        XCTAssertEqual(bridge.lastPrefsSet?.shareHiddenFiles, true)
    }

    @MainActor
    func testSetFilePrefsRejectsInvalidMinFreeSpace() {
        let model = AppModel()
        model.bridgeOps = ["prefs-connection-set"]
        model.minFreeDiskSpaceInput = "-1"

        model.setFilePrefs()

        XCTAssertEqual(model.lastError, "Minimum free disk space must be a non-negative integer.")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testSetFilePrefsWritesOnlyFilesGroup() async {
        let bridge = FakeBridgeAdapter()
        let model = AppModel(bridge: bridge)
        model.bridgeOps = ["prefs-connection-get", "prefs-connection-set"]
        model.newFilesPaused = false
        model.autoDownloadPriority = false
        model.previewPriority = false
        model.autoUploadPriority = false
        model.saveSources = false
        model.extractMetadata = false
        model.allocateFullFileSize = false
        model.checkFreeSpace = false
        model.minFreeDiskSpaceInput = "256"
        model.createSparseFiles = true

        model.setFilePrefs()
        await waitForPreferenceWrite(in: model, bridge: bridge)

        XCTAssertEqual(bridge.lastPrefsGroup, .files)
        XCTAssertEqual(bridge.lastPrefsSet?.newFilesPaused, false)
        XCTAssertEqual(bridge.lastPrefsSet?.autoDownloadPriority, false)
        XCTAssertEqual(bridge.lastPrefsSet?.previewPriority, false)
        XCTAssertEqual(bridge.lastPrefsSet?.autoUploadPriority, false)
        XCTAssertEqual(bridge.lastPrefsSet?.saveSources, false)
        XCTAssertEqual(bridge.lastPrefsSet?.extractMetadata, false)
        XCTAssertEqual(bridge.lastPrefsSet?.allocateFullFileSize, false)
        XCTAssertEqual(bridge.lastPrefsSet?.checkFreeSpace, false)
        XCTAssertEqual(bridge.lastPrefsSet?.minFreeDiskSpaceMB, 256)
        XCTAssertEqual(bridge.lastPrefsSet?.createSparseFiles, true)
    }

    @MainActor
    private func waitForPreferenceWrite(in model: AppModel, bridge: FakeBridgeAdapter) async {
        for _ in 0..<100 where bridge.lastPrefsGroup == nil || model.isBusy {
            await Task.yield()
        }
    }
}

final class RemainingParityTests: XCTestCase {
    func testDecodeCategoriesFriendsAndStatsEnvelope() throws {
        let json = #"{"ok":true,"categories":[{"id":1,"title":"Videos","path":"/tmp/videos","comment":"media","color":16777215,"priority":2}],"friends":[{"id":11,"name":"Alice","hash":"0123456789ABCDEF0123456789ABCDEF","ip":"1.2.3.4","port":4662,"client":"42","friend_slot":true}],"stats":{"graphs":{"last":123.5,"samples":[{"dl":1,"ul":2,"connections":3,"kad":4}]},"tree":{"id":7,"label":"Root","value":10,"children":[{"id":8,"label":"Child","value":5,"children":[]}]}}}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.categories?.first?.title, "Videos")
        XCTAssertEqual(decoded.friends?.first?.name, "Alice")
        XCTAssertEqual(decoded.stats?.graphs?.samples.first?.connections, 3)
        XCTAssertEqual(decoded.stats?.tree?.children.count, 1)
    }

    @MainActor
    func testRefreshCategoriesReadsWithoutAdvertisedCapability() async {
        let bridge = FakeBridgeAdapter()
        bridge.categoriesResult = ([BridgeCategoryPayload(id: 5, title: "Music", path: "", comment: "", color: 0, priority: 0)], #"{"ok":true,"categories":[{"id":5,"title":"Music"}]}"#)
        let model = AppModel(bridge: bridge)
        model.bridgeOps = ["status", "downloads"]

        model.refreshCategories()
        for _ in 0..<100 where model.isBusy || !bridge.invokedOperations.contains("categories") {
            await Task.yield()
        }

        XCTAssertEqual(model.lastError, "")
        XCTAssertEqual(model.categories.map(\.title), ["Music"])
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testFriendsGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads"]

        model.refreshFriends()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testStatsGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads"]

        model.refreshStatsTree()
        model.refreshStatsGraphs()
        XCTAssertEqual(model.lastError, "previous")
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testIpFilterURLValidationRejectsInvalidScheme() {
        let model = AppModel()
        model.bridgeOps = ["ipfilter-update"]

        model.updateIpFilterFromURL("ftp://example.com/filter.dat")
        XCTAssertFalse(model.lastError.isEmpty)
        XCTAssertFalse(model.isBusy)
    }
}
