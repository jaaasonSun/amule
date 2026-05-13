import Foundation

struct IOSFakeBridge: Sendable {
    struct Capabilities: Sendable {
        let schemaVersion: Int
        let ops: [String]
        let message: String
    }

    let capabilities = Capabilities(
        schemaVersion: 1,
        ops: ["capabilities"],
        message: "Fake iOS bridge placeholder"
    )
}
