#if canImport(XCTest) && canImport(AMuleECProtocol)
import XCTest
@testable import AMuleECProtocol

final class ECPacketHeaderTests: XCTestCase {
    func testHeaderEncodesBigEndianFlagsAndBodyLength() throws {
        let header = ECPacketHeader(flags: 0x01020304, bodyLength: 0x05060708)

        XCTAssertEqual(Array(header.encode()), [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        XCTAssertEqual(try ECPacketHeader.decode(header.encode()), header)
    }

    func testHeaderRejectsWrongLength() {
        XCTAssertThrowsError(try ECPacketHeader.decode(Data([0x00]))) { error in
            XCTAssertEqual(error as? ECProtocolError, .malformedHeader(expected: 8, actual: 1))
        }
    }

    func testPacketDecodeRejectsInvalidRequiredAndUnknownHeaderFlags() throws {
        let invalidRequiredFlags: [UInt32] = [0x0000_0000, 0x0000_0040, 0x0000_0060]
        for flags in invalidRequiredFlags {
            XCTAssertThrowsError(try ECPacket.decode(try Self.packetBytes(flags: flags))) { error in
                XCTAssertEqual(error as? ECProtocolError, .invalidPacketFlags(flags))
            }
        }

        let unknownFlags = ECPacket.requiredFlagValue | ECPacket.unknownFlagMask
        XCTAssertThrowsError(try ECPacket.decode(try Self.packetBytes(flags: unknownFlags))) { error in
            XCTAssertEqual(error as? ECProtocolError, .invalidPacketFlags(unknownFlags))
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
