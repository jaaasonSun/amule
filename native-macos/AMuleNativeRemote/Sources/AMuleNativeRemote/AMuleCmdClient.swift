import Foundation

struct AMuleConnectionConfig {
    var commandPath: String
    var host: String
    var port: Int
    var password: String

    static let legacyFallbackCommandPath = "/path/to/amule/build/src/amulecmd"

    static var bundledCommandPath: String? {
        let fm = FileManager.default
        if let resource = Bundle.main.resourceURL?.appendingPathComponent("amulecmd").path,
           fm.isExecutableFile(atPath: resource) {
            return resource
        }

        let appBundlePath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/amulecmd")
            .path
        if fm.isExecutableFile(atPath: appBundlePath) {
            return appBundlePath
        }

        return nil
    }

    static func preferredDefaultPath() -> String {
        let fm = FileManager.default
        if let bundled = bundledCommandPath {
            return bundled
        }

        let candidates = [
            legacyFallbackCommandPath,
            "/opt/homebrew/bin/amulecmd",
            "/usr/local/bin/amulecmd"
        ]
        for candidate in candidates where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return legacyFallbackCommandPath
    }
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

    static func runScriptWithDelays(
        _ commands: [String],
        delayBetweenCommandsNanoseconds: UInt64,
        config: AMuleConnectionConfig
    ) async throws -> String {
        guard let executablePath = resolveExecutablePath(config.commandPath) else {
            throw AMuleClientError.missingCommand(config.commandPath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = baseArguments(config)
            process.environment = utf8ProcessEnvironment()

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            let inputPipe = Pipe()
            process.standardInput = inputPipe

            process.terminationHandler = { process in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let text = decodeOutputData(data)
                if process.terminationStatus == 0 {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: AMuleClientError.processFailure(process.terminationStatus, text))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            Task.detached {
                for command in commands {
                    if let data = (command + "\n").data(using: .utf8) {
                        inputPipe.fileHandleForWriting.write(data)
                    }
                    if delayBetweenCommandsNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: delayBetweenCommandsNanoseconds)
                    }
                }
                if let quitData = "quit\n".data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(quitData)
                }
                try? inputPipe.fileHandleForWriting.close()
            }
        }
    }

    private static func run(arguments: [String], stdin: String?, commandPath: String) async throws -> String {
        guard let executablePath = resolveExecutablePath(commandPath) else {
            throw AMuleClientError.missingCommand(commandPath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.environment = utf8ProcessEnvironment()

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            let inputPipe = Pipe()
            if stdin != nil {
                process.standardInput = inputPipe
            }

            process.terminationHandler = { process in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let text = decodeOutputData(data)
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

    private static func resolveExecutablePath(_ commandPath: String) -> String? {
        let fm = FileManager.default
        let expanded = (commandPath as NSString).expandingTildeInPath

        if expanded.contains("/") {
            return fm.isExecutableFile(atPath: expanded) ? expanded : nil
        }

        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in envPath.split(separator: ":") {
            let fullPath = String(dir) + "/" + expanded
            if fm.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

        return nil
    }

    private static func utf8ProcessEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if env["LANG"]?.localizedCaseInsensitiveContains("UTF-8") != true {
            env["LANG"] = "en_US.UTF-8"
        }
        if env["LC_ALL"]?.localizedCaseInsensitiveContains("UTF-8") != true {
            env["LC_ALL"] = "en_US.UTF-8"
        }
        env["LC_CTYPE"] = "UTF-8"
        return env
    }

    private static func decodeOutputData(_ data: Data) -> String {
        let candidates: [String.Encoding] = [
            .utf8,
            gb18030Encoding(),
            big5Encoding(),
            .shiftJIS,
            eucKREncoding(),
            .isoLatin1,
            .windowsCP1252
        ]

        var bestText: String?
        var bestReplacementCount = Int.max

        for encoding in candidates {
            if let text = String(data: data, encoding: encoding) {
                let replacementCount = text.filter { $0 == "\u{FFFD}" }.count
                if replacementCount < bestReplacementCount {
                    bestReplacementCount = replacementCount
                    bestText = text
                    if replacementCount == 0 {
                        break
                    }
                }
            }
        }

        return bestText ?? String(decoding: data, as: UTF8.self)
    }

    private static func gb18030Encoding() -> String.Encoding {
        let cf = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let ns = CFStringConvertEncodingToNSStringEncoding(cf)
        return String.Encoding(rawValue: ns)
    }

    private static func big5Encoding() -> String.Encoding {
        let cf = CFStringEncoding(CFStringEncodings.big5.rawValue)
        let ns = CFStringConvertEncodingToNSStringEncoding(cf)
        return String.Encoding(rawValue: ns)
    }

    private static func eucKREncoding() -> String.Encoding {
        let cf = CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)
        let ns = CFStringConvertEncodingToNSStringEncoding(cf)
        return String.Encoding(rawValue: ns)
    }
}
