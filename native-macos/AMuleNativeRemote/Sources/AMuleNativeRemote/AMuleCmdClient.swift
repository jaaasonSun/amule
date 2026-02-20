import Foundation

struct AMuleConnectionConfig {
    var commandPath: String
    var host: String
    var port: Int
    var password: String

    static let fallbackCommandPath = "/path/to/amule/build/src/amulecmd"
}

enum AMuleClientError: LocalizedError {
    case missingCommand(String)
    case processFailure(Int32, String)

    var errorDescription: String? {
        switch self {
        case .missingCommand(let path):
            return "amulecmd not found at: \(path)"
        case .processFailure(let code, let output):
            return "amulecmd exited with code \(code).\n\(output)"
        }
    }
}

enum AMuleCmdClient {
    private static func baseArguments(_ config: AMuleConnectionConfig) -> [String] {
        [
            "-h", config.host,
            "-p", String(config.port),
            "-P", config.password
        ]
    }

    static func runCommand(_ command: String, config: AMuleConnectionConfig) async throws -> String {
        try await run(arguments: baseArguments(config) + ["-c", command], stdin: nil, commandPath: config.commandPath)
    }

    static func runScript(_ commands: [String], config: AMuleConnectionConfig) async throws -> String {
        let joined = (commands + ["quit"]).joined(separator: "\n") + "\n"
        return try await run(arguments: baseArguments(config), stdin: joined, commandPath: config.commandPath)
    }

    private static func run(arguments: [String], stdin: String?, commandPath: String) async throws -> String {
        guard FileManager.default.fileExists(atPath: commandPath) else {
            throw AMuleClientError.missingCommand(commandPath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: commandPath)
            process.arguments = arguments

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            let inputPipe = Pipe()
            if stdin != nil {
                process.standardInput = inputPipe
            }

            process.terminationHandler = { process in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(decoding: data, as: UTF8.self)
                if process.terminationStatus == 0 {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: AMuleClientError.processFailure(process.terminationStatus, text))
                }
            }

            do {
                try process.run()
                if let stdin, let data = stdin.data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(data)
                    try? inputPipe.fileHandleForWriting.close()
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
