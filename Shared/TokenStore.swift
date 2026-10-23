import Foundation
import Security

struct Tokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

/// Items live in the keychain access group shared by the app and the widget extension
/// (the first group in both targets' `keychain-access-groups` entitlement, so no explicit group is needed).
private enum KeychainItem {
    static let service = "MusicWidget.spotify"

    private static func base(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    static func load(_ account: String) -> Data? {
        var query = base(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    static func save(_ data: Data, account: String) {
        let status = SecItemUpdate(base(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var query = base(account)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func delete(_ account: String) {
        SecItemDelete(base(account) as CFDictionary)
    }
}

enum TokenStore {
    private static let account = "tokens"

    static func load() -> Tokens? {
        KeychainItem.load(account).flatMap { try? JSONDecoder().decode(Tokens.self, from: $0) }
    }

    static func save(_ tokens: Tokens) {
        if let data = try? JSONEncoder().encode(tokens) { KeychainItem.save(data, account: account) }
    }

    static func clear() { KeychainItem.delete(account) }
}

/// A Client ID the user entered themselves ("bring your own Spotify app"). Shared with the widget
/// so token refreshes use the same app that issued the tokens.
enum ClientIDStore {
    private static let account = "clientID"

    static func load() -> String? {
        KeychainItem.load(account).flatMap { String(data: $0, encoding: .utf8) }.flatMap { $0.isEmpty ? nil : $0 }
    }

    static func save(_ id: String) {
        KeychainItem.save(Data(id.utf8), account: account)
    }

    static func clear() { KeychainItem.delete(account) }
}
