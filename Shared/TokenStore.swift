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

/// The look chosen in the app (theme, accent, corners). Widgets set to "Same as app" read it from here.
/// It rides in the shared keychain group so no extra App Group entitlement is needed.
enum StyleStore {
    private static let account = "style"

    static func load() -> WidgetStyle {
        var style = KeychainItem.load(account).flatMap { try? JSONDecoder().decode(WidgetStyle.self, from: $0) } ?? WidgetStyle()
        // "Same as app" is only meaningful on a widget; the app itself always stores concrete values.
        if style.theme == .appDefault { style.theme = .system }
        if style.accent == .appDefault { style.accent = .themeDefault }
        if style.corners == .appDefault { style.corners = .soft }
        return style
    }

    static func save(_ style: WidgetStyle) {
        if let data = try? JSONEncoder().encode(style) { KeychainItem.save(data, account: account) }
    }
}
