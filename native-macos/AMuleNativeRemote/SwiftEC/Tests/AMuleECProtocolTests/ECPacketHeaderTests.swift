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
}
#endif
