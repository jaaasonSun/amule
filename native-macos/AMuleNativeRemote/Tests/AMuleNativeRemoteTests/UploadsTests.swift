import XCTest

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

final class SharedFilesTests: XCTestCase {
    func testDecodeSharedFilesEnvelope() throws {
        let json = #"{"ok":true,"shared_files":[{"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"File A","path":"/tmp/file-a.bin","size":1234,"ed2k_link":"ed2k://|file|file-a.bin|1234|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/","priority":10,"requests":1,"requests_all":5,"accepts":1,"accepts_all":4,"xferred":100,"xferred_all":200,"comment":"hello","rating":4},{"hash":"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB","name":"File B","path":"/tmp/file-b.bin","size":42,"ed2k_link":"","priority":5,"requests":0,"requests_all":0,"accepts":0,"accepts_all":0,"xferred":0,"xferred_all":0}]}"#
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
        let json = #"{"ok":true,"prefs_connection":{"max_dl":512,"max_ul":64}}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.prefsConnection?.maxDownload, 512)
        XCTAssertEqual(decoded.prefsConnection?.maxUpload, 64)
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
    func testCategoriesGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads"]

        model.refreshCategories()
        XCTAssertEqual(model.lastError, "previous")
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
