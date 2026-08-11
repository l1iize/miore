import Foundation
import Security

/// Stores credentials in the user's login Keychain instead of the preferences file.
final class SecureStore: @unchecked Sendable {
    static let shared = SecureStore()

    private let service = Bundle.main.bundleIdentifier ?? "dev.miore.launcher"

    private init() {}

    func string(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func set(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query = baseQuery(forKey: key)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func remove(_ key: String) -> Bool {
        let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Moves credentials written by older releases out of config.json.
    func migrate(key: String, from config: LocalConfigStore) {
        guard string(forKey: key) == nil, let legacy = config.string(forKey: key), !legacy.isEmpty else {
            if string(forKey: key) != nil { config.removeObject(forKey: key) }
            return
        }
        if set(legacy, forKey: key) { config.removeObject(forKey: key) }
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
