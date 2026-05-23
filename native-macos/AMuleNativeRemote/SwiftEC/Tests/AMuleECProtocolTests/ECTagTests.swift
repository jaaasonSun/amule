#if canImport(XCTest) && canImport(AMuleECProtocol) && canImport(Fixtures)
import XCTest
@testable import AMuleECProtocol
import Fixtures

final class ECTagTests: XCTestCase {
    func testGoldenFixturesDecodeAndReencodeExactly() throws {
        for fixture in ECTagFixtures.allTags {
            let encoded = Data(fixture.bytes)
            let tag = try ECTag.decode(encoded)

            XCTAssertEqual(tag.name, fixture.tagName, fixture.name)
            XCTAssertEqual(tag.type.rawValue, fixture.type, fixture.name)
            XCTAssertEqual(try tag.encode(), encoded, fixture.name)
        }
    }

    func testMinimalWidthIntegersMatchGoldenFixtures() throws {
        let cases: [(ECTag, [UInt8])] = [
            (.integer(name: 0x0004, value: 2), ECTagFixtures.uint8Tag.bytes),
            (.integer(name: 0x0002, value: 0x0204), ECTagFixtures.uint16Tag.bytes),
            (.integer(name: 0x000f, value: 0x01020304), ECTagFixtures.uint32Tag.bytes),
            (.integer(name: 0x0303, value: 0x0102030405060708), ECTagFixtures.uint64Tag.bytes),
        ]

        for (tag, bytes) in cases {
            XCTAssertEqual(try tag.encode(), Data(bytes))
        }
    }

    func testSpecificTypedValuesDecode() throws {
        XCTAssertEqual(try ECTag.decode(Data(ECTagFixtures.stringTag.bytes)).value, .string("aMuleNativeBridge"))
        XCTAssertEqual(try ECTag.decode(Data(ECTagFixtures.doubleTag.bytes)).value, .double(3.5))
        XCTAssertEqual(try ECTag.decode(Data(ECTagFixtures.ipv4Tag.bytes)).value, .ipv4(ECIPv4Address(1, 2, 3, 4, port: 4662)))
        XCTAssertEqual(try ECTag.decode(Data(ECTagFixtures.hash16Tag.bytes)).value, .hash16(Data(Array(UInt8(0)...UInt8(15)))))
    }

    func testUInt128TagRoundTrips() throws {
        let bytes = Data(Array(UInt8(0)...UInt8(15)))
        let tag = ECTag(name: 0x0010, type: .uint128, value: .uint128(bytes))
        let encoded = try tag.encode()

        XCTAssertEqual(Array(encoded.prefix(7)), [0x00, 0x20, 0x0a, 0x00, 0x00, 0x00, 0x10])
        XCTAssertEqual(try ECTag.decode(encoded), tag)
    }

    func testNestedTagDecodesChildrenAndReencodes() throws {
        let tag = try ECTag.decode(Data(ECTagFixtures.nestedTag.bytes))

        XCTAssertEqual(tag.name, 0x0300)
        XCTAssertEqual(tag.type, .custom)
        XCTAssertEqual(tag.children.count, 2)
        XCTAssertEqual(tag.children[0].name, 0x0309)
        XCTAssertEqual(tag.children[0].value, .uint(1))
        XCTAssertEqual(tag.children[1].name, 0x0301)
        XCTAssertEqual(tag.children[1].value, .string("child"))
        XCTAssertEqual(try tag.encode(), Data(ECTagFixtures.nestedTag.bytes))
    }

    func testEmptyTagRoundTrips() throws {
        let tag = ECTag(name: 0x0011, type: .custom, value: .empty)
        let encoded = try tag.encode()

        XCTAssertEqual(Array(encoded), [0x00, 0x22, 0x01, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(try ECTag.decode(encoded), tag)
    }

    func testMalformedTagsReturnTypedErrors() {
        XCTAssertThrowsError(try ECTag.decode(Data([0x00, 0x02, 0xff, 0x00, 0x00, 0x00, 0x00]))) { error in
            XCTAssertEqual(error as? ECProtocolError, .unknownTagType(0xff))
        }

        XCTAssertThrowsError(try ECTag.decode(Data([0x00, 0x08, 0x02, 0x00, 0x00, 0x00, 0x02, 0x01, 0x02]))) { error in
            XCTAssertEqual(error as? ECProtocolError, .invalidTagData(type: ECTagType.uint8.rawValue, length: 2))
        }
    }
}
#endif
