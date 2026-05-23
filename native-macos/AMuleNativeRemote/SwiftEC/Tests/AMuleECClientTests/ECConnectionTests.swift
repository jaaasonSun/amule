import XCTest
@preconcurrency import Network
import Foundation
import AMuleECProtocol
@testable import AMuleECClient

@available(macOS 10.14, iOS 12.0, *)
final class ECConnectionTests: XCTestCase {
    func testLoopbackConnectionSendsAndReceivesPacket() async throws {
        let listener = try NWListener(using: .tcp, on: .any)
        let ready = expectation(description: "listener ready")
        let serverQueue = DispatchQueue(label: "org.amule.swift-ec.tests.loopback")
        let request = ECPacket(flags: ECAuthPacket.baseFlags, opcode: 0x30)
        let response = ECPacket(flags: ECAuthPacket.baseFlags, opcode: 0x31)

        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.fulfill() }
        }
        listener.newConnectionHandler = { connection in
            connection.start(queue: serverQueue)
            Self.receivePacket(on: connection) { result in
                guard case .success(let data) = result,
                      let packet = try? ECPacket.decode(data),
                      packet.opcode == request.opcode,
                      let responseData = try? response.encode()
                else {
                    connection.cancel()
                    return
                }
                connection.send(content: responseData, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
        listener.start(queue: serverQueue)
        await fulfillment(of: [ready], timeout: 2)

        guard let port = listener.port else {
            XCTFail("Listener did not publish a port")
            return
        }

        let connection = ECConnection(endpoint: .hostPort(host: .ipv4(.loopback), port: port))
        try await connection.connect(timeout: 2)
        try await connection.send(request, timeout: 2)
        let reply = try await connection.receivePacket(timeout: 2, partialReadTimeout: 2)
        await connection.disconnect()
        listener.cancel()

        XCTAssertEqual(reply.opcode, response.opcode)
    }

    private static func receivePacket(on connection: NWConnection, completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        connection.receive(minimumIncompleteLength: ECPacketHeader.byteCount, maximumLength: ECPacketHeader.byteCount) { headerData, _, _, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let headerData, headerData.count == ECPacketHeader.byteCount,
                  let header = try? ECPacketHeader.decode(headerData)
            else {
                completion(.failure(ECSessionError.protocolError("Missing loopback header")))
                return
            }
            let bodyLength = Int(header.bodyLength)
            connection.receive(minimumIncompleteLength: bodyLength, maximumLength: bodyLength) { bodyData, _, _, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let bodyData, bodyData.count == bodyLength else {
                    completion(.failure(ECSessionError.protocolError("Missing loopback body")))
                    return
                }
                var data = headerData
                data.append(bodyData)
                completion(.success(data))
            }
        }
    }
}
