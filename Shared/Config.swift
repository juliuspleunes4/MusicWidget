import Foundation

enum AppConfig {
    /// Optional default Client ID shipped inside the app (the release workflow fills this in from the
    /// SPOTIFY_CLIENT_ID repo variable). Spotify limits how many people one app can serve, so users can
    /// instead enter their own Client ID in the app; that choice takes priority.
    /// PKCE: no client secret is used or needed.
    static let builtInClientID = "YOUR_SPOTIFY_CLIENT_ID"

    static var clientID: String { ClientIDStore.load() ?? builtInClientID }

    /// Add `musicwidget://callback` as a Redirect URI in the Spotify dashboard.
    static let redirectScheme = "musicwidget"
    static var redirectURI: String { "\(redirectScheme)://callback" }

    static let scopes = [
        "user-read-currently-playing",
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-recently-played",
        "user-library-read",
        "user-top-read",
    ]

    static let widgetKind = "MusicWidget"
    static var isConfigured: Bool { !clientID.isEmpty && !clientID.hasPrefix("YOUR_") }
}
