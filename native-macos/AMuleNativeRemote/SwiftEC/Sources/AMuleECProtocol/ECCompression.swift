import Compression
import Foundation

public enum ECCompression {
    public static let flag: UInt32 = 0x0000_0001
    public static let threshold = 100
    public static let maximumDecompressedSize = 64 * 1024 * 1024

    public static func compress(_ data: Data) throws -> Data {
        try transform(data, operation: COMPRESSION_STREAM_ENCODE)
    }

    public static func decompress(_ data: Data, maximumOutputSize: Int = maximumDecompressedSize) throws -> Data {
        try transform(data, operation: COMPRESSION_STREAM_DECODE, maximumOutputSize: maximumOutputSize)
    }

    private static func transform(
        _ data: Data,
        operation: compression_stream_operation,
        maximumOutputSize: Int = maximumDecompressedSize
    ) throws -> Data {
        guard !data.isEmpty else { return Data() }

        var initialSource = UInt8(0)
        var initialDestination = UInt8(0)
        var stream = withUnsafeMutablePointer(to: &initialDestination) { destination in
            withUnsafePointer(to: &initialSource) { source in
                compression_stream(dst_ptr: destination, dst_size: 0, src_ptr: source, src_size: 0, state: nil)
            }
        }
        let status = compression_stream_init(&stream, operation, COMPRESSION_ZLIB)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw ECProtocolError.compressionFailed(operation: operation.errorName)
        }
        defer { compression_stream_destroy(&stream) }

        return try data.withUnsafeBytes { source in
            guard let sourceAddress = source.bindMemory(to: UInt8.self).baseAddress else { return Data() }
            stream.src_ptr = sourceAddress
            stream.src_size = source.count

            var output = Data()
            let chunkSize = 16 * 1024
            let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
            defer { destination.deallocate() }

            var streamStatus: compression_status
            repeat {
                stream.dst_ptr = destination
                stream.dst_size = chunkSize
                streamStatus = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

                let written = chunkSize - stream.dst_size
                if written > 0 {
                    if output.count + written > maximumOutputSize {
                        throw ECProtocolError.decompressionLimitExceeded(limit: maximumOutputSize)
                    }
                    output.append(destination, count: written)
                }

                if streamStatus == COMPRESSION_STATUS_ERROR {
                    throw ECProtocolError.compressionFailed(operation: operation.errorName)
                }
            } while streamStatus == COMPRESSION_STATUS_OK

            return output
        }
    }
}

private extension compression_stream_operation {
    var errorName: String {
        self == COMPRESSION_STREAM_ENCODE ? "deflate" : "inflate"
    }
}
