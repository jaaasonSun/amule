#if canImport(XCTest) && canImport(AMuleECProtocol)
import XCTest
@testable import AMuleECProtocol

final class ECCompressionTests: XCTestCase {
    func testCompressionRoundTrip() throws {
        let packet = largePacket()
        let encoded = try packet.encode(compressionEnabled: true)
        let decoded = try ECPacket.decode(encoded)

        XCTAssertEqual(decoded, ECPacket(flags: ECPacket.protocolBaseFlags | ECCompression.flag, opcode: packet.opcode, tags: packet.tags))
    }

    func testSmallPacketsAreNotCompressedBelowThreshold() throws {
        let packet = ECPacket(opcode: 0x06, tags: [.integer(name: 0x0001, value: 42)])
        let encoded = try packet.encode(compressionEnabled: true)
        let header = try ECPacketHeader.decode(encoded.prefix(ECPacketHeader.byteCount))

        XCTAssertEqual(header.flags & ECCompression.flag, 0)
        XCTAssertEqual(Int(header.bodyLength), try packet.encodeBody().count)
        XCTAssertEqual(try ECPacket.decode(encoded), packet)
    }

    func testMalformedCompressedPacketThrowsTypedError() throws {
        var data = ECPacketHeader(flags: ECPacket.protocolBaseFlags | ECCompression.flag, bodyLength: 4).encode()
        data.append(contentsOf: [0xde, 0xad, 0xbe, 0xef])

        XCTAssertThrowsError(try ECPacket.decode(data)) { error in
            XCTAssertEqual(error as? ECProtocolError, .compressionFailed(operation: "inflate"))
        }
    }

    func testCompressedPacketHeaderAndBodyMatchCPPZlibExpectations() throws {
        let packet = largePacket(flags: 0x0000_0020)
        let body = try packet.encodeBody()
        let encoded = try packet.encode(compressionEnabled: true)
        let header = try ECPacketHeader.decode(encoded.prefix(ECPacketHeader.byteCount))
        let compressedBody = Data(encoded.dropFirst(ECPacketHeader.byteCount))

        XCTAssertEqual(header.flags, 0x0000_0021)
        XCTAssertEqual(Array(encoded.prefix(4)), [0x00, 0x00, 0x00, 0x21])
        XCTAssertEqual(Int(header.bodyLength), compressedBody.count)
        XCTAssertTrue(compressedBody.count < body.count)
        XCTAssertEqual(try ECCompression.decompress(compressedBody), body)
    }

    private func largePacket(flags: UInt32 = 0) -> ECPacket {
        let payload = Data(repeating: 0x41, count: 512)
        let tag = ECTag(name: 0x0001, type: .custom, value: .custom(payload))
        return ECPacket(flags: flags == 0 ? ECPacket.protocolBaseFlags : flags, opcode: 0x06, tags: [tag])
    }
}
#endif
