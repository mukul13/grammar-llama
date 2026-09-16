import Foundation
import Security

enum Keychain {
    private static let service = "com.sidepanda.GrammarLlama"
    private static let legacyService = "com.sidepanda.Polish"
    private static let anthropicAccount = "anthropic-api-key"
    private static let openAIAccount = "openai-api-key"

    static var anthropicKey: String? {
        get { read(account: anthropicAccount) }
        set { set(newValue, account: anthropicAccount) }
    }
    static var openAIKey: String? {
        get { read(account: openAIAccount) }
        set { set(newValue, account: openAIAccount) }
    }
    static var hasAnyKey: Bool { anthropicKey != nil || openAIKey != nil }

    private static func set(_ value: String?, account: String) {
        if let v = value, !v.isEmpty { write(v, account: account) } else { delete(account: account) }
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private static func read(account: String) -> String? {
        if let v = read(service: service, account: account) { return v }
        // Migrate a key saved under the app's previous name.
        if let legacy = read(service: legacyService, account: account) {
            write(legacy, account: account)
            return legacy
        }
        return nil
    }

    private static func read(service: String, account: String) -> String? {
        var q = baseQuery(account: account)
        q[kSecAttrService as String] = service
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String, account: String) {
        let data = Data(value.utf8)
        let q = baseQuery(account: account)
        let status = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = q
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    private static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
