#if canImport(XCTest) && canImport(AMuleECProtocol) && canImport(Fixtures)
import XCTest
@testable import AMuleECProtocol
import Fixtures

final class ECPacketTests: XCTestCase {
    func testPacketBodyDecodesGoldenAggregateFixture() throws {
        let body = Data(ECTagFixtures.aggregatePacketBody)
        let packet = try ECPacket.decodeBody(body)

        XCTAssertEqual(packet.opcode, 0x06)
        XCTAssertEqual(packet.tags.count, ECTagFixtures.allTags.count)
        XCTAssertEqual(try packet.encodeBody(), body)
    }

    func testFullPacketHeaderBodyRoundTrip() throws {
        let body = Data(ECTagFixtures.aggregatePacketBody)
        let packet = try ECPacket.decodeBody(body, flags: ECPacket.protocolBaseFlags)
        let encoded = try packet.encode()

        XCTAssertEqual(Array(encoded.prefix(8)), [0x00, 0x00, 0x00, 0x20, 0x00, 0x00, 0x00, UInt8(body.count)])
        XCTAssertEqual(try ECPacket.decode(encoded), packet)
    }

    func testPacketRejectsBodyLengthMismatch() {
        let bytes = Data([0x00, 0x00, 0x00, 0x20, 0x00, 0x00, 0x00, 0x02, 0x06])

        XCTAssertThrowsError(try ECPacket.decode(bytes)) { error in
            XCTAssertEqual(error as? ECProtocolError, .invalidLength(field: "packet body", expected: 2, actual: 1))
        }
    }

    func testPacketRejectsMissingProtocolBaseFlags() throws {
        let bytes = try Self.packetBytes(flags: 0x0000_0000)

        XCTAssertThrowsError(try ECPacket.decode(bytes)) { error in
            XCTAssertEqual(error as? ECProtocolError, .invalidPacketFlags(0x0000_0000))
        }
    }

    func testPacketRejectsUnknownHeaderFlags() throws {
        let bytes = try Self.packetBytes(flags: ECPacket.protocolBaseFlags | 0x0000_0008)

        XCTAssertThrowsError(try ECPacket.decode(bytes)) { error in
            XCTAssertEqual(error as? ECProtocolError, .invalidPacketFlags(ECPacket.protocolBaseFlags | 0x0000_0008))
        }
    }

    private static func packetBytes(flags: UInt32) throws -> Data {
        let body = try ECPacket(opcode: 0x04).encodeBody()
        var bytes = ECPacketHeader(flags: flags, bodyLength: UInt32(body.count)).encode()
        bytes.append(body)
        return bytes
    }
}
#endif
