import Foundation
import Security

public struct KeychainCredentialStorage: CredentialStorage, @unchecked Sendable {
    private let service: String
    private let accessibility: CFString?

    public init(service: String, accessibility: CFString? = nil) {
        self.service = service
        self.accessibility = accessibility
    }

    public func readCredential(forKey key: String) -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(readQuery(forKey: key) as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func writeCredential(_ credential: String, forKey key: String) {
        guard let data = credential.data(using: .utf8) else { return }
        let status = SecItemAdd(writeQuery(forKey: key, data: data) as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [CFString: Any] = [kSecValueData: data]
            SecItemUpdate(baseQuery(forKey: key) as CFDictionary, update as CFDictionary)
        }
    }

    public func deleteCredential(forKey key: String) {
        SecItemDelete(baseQuery(forKey: key) as CFDictionary)
    }

    private func readQuery(forKey key: String) -> [CFString: Any] {
        var query = baseQuery(forKey: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        return query
    }

    private func writeQuery(forKey key: String, data: Data) -> [CFString: Any] {
        var query = baseQuery(forKey: key)
        query[kSecValueData] = data
        if let accessibility {
            query[kSecAttrAccessible] = accessibility
        }
        return query
    }

    private func baseQuery(forKey key: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
    }
}
