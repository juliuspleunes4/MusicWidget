import Foundation
import CryptoKit

enum SpotifyError: Error, LocalizedError {
    case signedOut
    case http(Int, String)
    case rateLimited
    case invalidResponse
    case authFailed(String)

    var errorDescription: String? {
        switch self {
        case .signedOut: return "Not signed in to Spotify."
        case .http(let code, _): return "Spotify returned an error (\(code))."
        case .rateLimited: return "Spotify is rate limiting requests. Try again shortly."
        case .invalidResponse: return "Unexpected response from Spotify."
        case .authFailed(let m): return m
        }
    }
}

/// OAuth 2.0 Authorization Code flow with PKCE (no client secret).
enum SpotifyAuth {
    static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URL
    }

    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
    }

    static func authorizeURL(challenge: String, state: String) -> URL {
        var c = URLComponents(string: "https://accounts.spotify.com/authorize")!
        c.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: AppConfig.clientID),
            .init(name: "scope", value: AppConfig.scopes.joined(separator: " ")),
            .init(name: "redirect_uri", value: AppConfig.redirectURI),
            .init(name: "state", value: state),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
        ]
        return c.url!
    }

    static func exchange(code: String, verifier: String) async throws -> Tokens {
        let r = try await tokenRequest([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": AppConfig.redirectURI,
            "client_id": AppConfig.clientID,
            "code_verifier": verifier,
        ])
        guard let refresh = r.refreshToken else { throw SpotifyError.invalidResponse }
        return Tokens(accessToken: r.accessToken, refreshToken: refresh,
                      expiresAt: Date().addingTimeInterval(TimeInterval(r.expiresIn)))
    }

    static func refresh(_ tokens: Tokens) async throws -> Tokens {
        let r = try await tokenRequest([
            "grant_type": "refresh_token",
            "refresh_token": tokens.refreshToken,
            "client_id": AppConfig.clientID,
        ])
        return Tokens(accessToken: r.accessToken, refreshToken: r.refreshToken ?? tokens.refreshToken,
                      expiresAt: Date().addingTimeInterval(TimeInterval(r.expiresIn)))
    }

    // MARK: -

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int
    }

    private static func tokenRequest(_ params: [String: String]) async throws -> TokenResponse {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        req.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw SpotifyError.invalidResponse }
        guard http.statusCode == 200 else {
            throw SpotifyError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TokenResponse.self, from: data)
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
