#if canImport(XCTest) && canImport(AMuleECProtocol) && canImport(Fixtures)
import XCTest
@testable import AMuleECProtocol
import Fixtures

final class ECLegacyAuthTests: XCTestCase {
    func testPlaintextPasswordsNormalizeToMD5FixtureValues() throws {
        for fixture in ECAuthFixtures.additionalKnownHashes {
            XCTAssertEqual(try ECLegacyAuth.normalizePassword(fixture.password), fixture.passwordMD5Hex)
        }
    }

    func testLowercasePrehashedPasswordIsAcceptedUnchanged() throws {
        let fixture = ECAuthFixtures.secretPasswordSalt1234ABCD

        XCTAssertEqual(try ECLegacyAuth.normalizePassword(fixture.passwordMD5Hex), fixture.passwordMD5Hex)
    }

    func testUppercasePrehashedPasswordIsAcceptedAndNormalized() throws {
        let fixture = ECAuthFixtures.secretPasswordSalt1234ABCD

        XCTAssertEqual(
            try ECLegacyAuth.normalizePassword(fixture.passwordMD5Hex.uppercased()),
            fixture.passwordMD5Hex
        )
    }

    func testSaltedMD5MatchesEveryFixtureExactly() throws {
        for fixture in ECAuthFixtures.additionalKnownHashes {
            XCTAssertEqual(ECLegacyAuth.saltHashHex(salt: fixture.saltUInt64), fixture.saltMD5Hex)
            XCTAssertEqual(try ECLegacyAuth.responseHashHex(password: fixture.password, salt: fixture.saltUInt64), fixture.responseMD5Hex)
            XCTAssertEqual(try ECLegacyAuth.responseHashHex(password: fixture.passwordMD5Hex, salt: fixture.saltUInt64), fixture.responseMD5Hex)
        }
    }

    func testAuthPasswordPacketMatchesGoldenBodyAndFullPacket() throws {
        let fixture = ECAuthFixtures.secretPasswordSalt1234ABCD
        let packet = try ECAuthPacket.authPassword(password: fixture.password, salt: fixture.saltUInt64)

        XCTAssertEqual(try packet.encodeBody(), Data(ECAuthFixtures.authPasswordPacketBody))
        XCTAssertEqual(try packet.encode(), Data(ECAuthFixtures.authPasswordPacketBytes))
    }

    func testAuthPasswordHashTagMatchesEveryFixture() throws {
        for fixture in ECAuthFixtures.additionalKnownHashes {
            let packet = try ECAuthPacket.authPassword(password: fixture.password, salt: fixture.saltUInt64)

            XCTAssertEqual(packet.tags.count, 1)
            XCTAssertEqual(try packet.tags[0].encode(), Data(fixture.passwordHashTagBytes))
        }
    }

    func testAuthRequestPacketContainsClientVersionAndProtocolVersion() throws {
        let packet = ECAuthPacket.authRequest(clientName: "aMuleNativeBridge", version: "0.1.0")

        XCTAssertEqual(packet.opcode, ECAuthPacket.opAuthReq)
        XCTAssertEqual(packet.tags, [
            ECTag(name: ECAuthPacket.tagClientName, type: .string, value: .string("aMuleNativeBridge")),
            ECTag(name: ECAuthPacket.tagClientVersion, type: .string, value: .string("0.1.0")),
            ECTag.integer(name: ECAuthPacket.tagProtocolVersion, value: ECAuthPacket.currentProtocolVersion),
        ])
    }

    func testSaltPacketParsingUsesPasswordSaltTag() throws {
        let packet = try ECPacket.decodeBody(Data(ECAuthFixtures.authSaltPacketBody))

        XCTAssertEqual(packet.opcode, ECAuthPacket.opAuthSalt)
        XCTAssertEqual(try ECLegacyAuth.parseSalt(from: packet), ECAuthFixtures.secretPasswordSalt1234ABCD.saltUInt64)
    }

    func testAuthResponseParsingAcceptsOKWithOptionalServerVersion() throws {
        let packet = ECPacket(
            opcode: ECAuthPacket.opAuthOK,
            tags: [ECTag(name: ECAuthPacket.tagServerVersion, type: .string, value: .string("2.3.3"))]
        )

        XCTAssertEqual(try ECLegacyAuth.parseAuthResponse(packet), .accepted(serverVersion: "2.3.3"))
    }

    func testAuthResponseParsingRejectsFailuresWithReason() {
        let packet = ECPacket(
            opcode: ECAuthPacket.opFailed,
            tags: [ECTag(name: ECAuthPacket.tagString, type: .string, value: .string("bad password"))]
        )

        XCTAssertThrowsError(try ECLegacyAuth.parseAuthResponse(packet)) { error in
            XCTAssertEqual(error as? ECLegacyAuthError, .authRejected("bad password"))
        }
    }

    func testPasswordValidationErrorsAreTyped() {
        XCTAssertThrowsError(try ECLegacyAuth.normalizePassword("")) { error in
            XCTAssertEqual(error as? ECLegacyAuthError, .emptyPassword)
        }

        XCTAssertThrowsError(try ECLegacyAuth.normalizePassword("d41d8cd98f00b204e9800998ecf8427e")) { error in
            XCTAssertEqual(error as? ECLegacyAuthError, .emptyPassword)
        }
    }

    func testInvalidMD5HexForPacketBuilderIsTyped() {
        XCTAssertThrowsError(try ECAuthPacket.authPassword(hashHex: "not-md5")) { error in
            XCTAssertEqual(error as? ECLegacyAuthError, .invalidMD5Hex("not-md5"))
        }
    }
}
#endif
