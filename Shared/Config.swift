import Foundation

enum AppConfig {
    /// Spotify Developer Dashboard → your app → Client ID. (PKCE: no client secret is used or needed.)
    static let clientID = "YOUR_SPOTIFY_CLIENT_ID"

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
    static var isConfigured: Bool { clientID != "YOUR_SPOTIFY_CLIENT_ID" && !clientID.isEmpty }
}
