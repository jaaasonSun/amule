import Foundation
import AMuleECClient

@available(macOS 10.15, iOS 13.0, *)
public enum RenameAcknowledgement: Equatable, Sendable {
    case success(message: String, raw: String)
    case failure(message: String, raw: String)
    case disconnectedAfterSend(message: String, raw: String)
    case timeout(message: String, raw: String)
    case requested(message: String, raw: String)

    public var message: String {
        switch self {
        case .success(let message, _),
             .failure(let message, _),
             .disconnectedAfterSend(let message, _),
             .timeout(let message, _),
             .requested(let message, _):
            return message
        }
    }

    public var raw: String {
        switch self {
        case .success(_, let raw),
             .failure(_, let raw),
             .disconnectedAfterSend(_, let raw),
             .timeout(_, let raw),
             .requested(_, let raw):
            return raw
        }
    }

    public var requiresPostRefreshVerification: Bool {
        switch self {
        case .failure:
            false
        case .success, .disconnectedAfterSend, .timeout, .requested:
            true
        }
    }

    public var verificationFailureMessage: String {
        switch self {
        case .timeout:
            return "EC request timed out. The filename was not changed."
        case .failure(let message, _):
            return message
        case .success, .disconnectedAfterSend, .requested:
            return "Rename request was sent, but the filename was not changed."
        }
    }

    static func ok(_ message: String, kind: Kind) throws -> Self {
        let raw = ECJSONEnvelope.jsonString(try ECJSONEnvelope.message(message))
        switch kind {
        case .success:
            return .success(message: message, raw: raw)
        case .disconnectedAfterSend:
            return .disconnectedAfterSend(message: message, raw: raw)
        case .timeout:
            return .timeout(message: message, raw: raw)
        case .requested:
            return .requested(message: message, raw: raw)
        case .failure:
            return .failure(message: message, raw: ECJSONEnvelope.jsonString(try ECJSONEnvelope.error(message)))
        }
    }

    static func failure(_ message: String) throws -> Self {
        .failure(message: message, raw: ECJSONEnvelope.jsonString(try ECJSONEnvelope.error(message)))
    }

    enum Kind {
        case success
        case failure
        case disconnectedAfterSend
        case timeout
        case requested
    }
}
