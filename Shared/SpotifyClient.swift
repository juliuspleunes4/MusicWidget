import Foundation

actor SpotifyClient {
    static let shared = SpotifyClient()

    private let session = URLSession(configuration: .ephemeral)
    private let base = URL(string: "https://api.spotify.com/v1")!
    private var refreshTask: Task<Tokens, Error>?

    // MARK: - Tokens

    /// Returns usable tokens. Pass `staleAccessToken` after a 401 to force a refresh
    /// (unless the other process — app or widget — already refreshed in the meantime).
    private func tokens(staleAccessToken stale: String? = nil) async throws -> Tokens {
        guard let current = TokenStore.load() else { throw SpotifyError.signedOut }
        if let stale {
            if current.accessToken != stale { return current }
        } else if current.expiresAt.timeIntervalSinceNow > 60 {
            return current
        }
        if let refreshTask { return try await refreshTask.value }

        let task = Task { () throws -> Tokens in
            do {
                let renewed = try await SpotifyAuth.refresh(current)
                TokenStore.save(renewed)
                return renewed
            } catch SpotifyError.http(let code, _) where code == 400 {
                TokenStore.clear()   // refresh token revoked → user must sign in again
                throw SpotifyError.signedOut
            }
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    // MARK: - Transport

    private func send(_ method: String, _ path: String, query: [String: String] = [:]) async throws -> (Data, Int) {
        var token = try await tokens().accessToken
        for attempt in 0..<2 {
            var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
            if !query.isEmpty { comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
            var req = URLRequest(url: comps.url!)
            req.httpMethod = method
            if method != "GET" { req.httpBody = Data() }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw SpotifyError.invalidResponse }
            if http.statusCode == 401, attempt == 0 {
                token = try await tokens(staleAccessToken: token).accessToken
                continue
            }
            if http.statusCode == 429 { throw SpotifyError.rateLimited }
            guard (200..<300).contains(http.statusCode) else {
                throw SpotifyError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
            }
            return (data, http.statusCode)
        }
        throw SpotifyError.invalidResponse
    }

    private func get<T: Decodable>(_ path: String, _ query: [String: String] = [:]) async throws -> T {
        let (data, _) = try await send("GET", path, query: query)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Reads

    func displayName() async throws -> String? {
        struct Me: Decodable { let displayName: String? }
        let me: Me = try await get("me")
        return me.displayName
    }

    /// `nil` when nothing is playing (HTTP 204), an ad is playing, or the item is unavailable.
    func playback() async throws -> PlaybackState? {
        let (data, status) = try await send("GET", "me/player/currently-playing",
                                            query: ["additional_types": "track,episode"])
        guard status == 200, !data.isEmpty else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dto = try decoder.decode(PlayerDTO.self, from: data)
        guard let track = dto.item, let item = track.artwork else { return nil }
        return PlaybackState(
            item: item,
            album: track.album?.name ?? track.show?.name ?? "",
            durationMs: track.durationMs ?? 0,
            progressMs: dto.progressMs ?? 0,
            isPlaying: dto.isPlaying ?? false,
            fetchedAt: Date()
        )
    }

    func recentAlbums(limit: Int) async throws -> [ArtworkItem] {
        let page: PagedDTO<RecentDTO> = try await get("me/player/recently-played", ["limit": "50"])
        var seen = Set<String>()
        var out: [ArtworkItem] = []
        for entry in page.items {
            guard let album = entry.track.album?.artwork, seen.insert(album.id).inserted else { continue }
            out.append(album)
            if out.count == limit { break }
        }
        return out
    }

    func savedAlbums(limit: Int) async throws -> [ArtworkItem] {
        let page: PagedDTO<SavedAlbumDTO> = try await get("me/albums", ["limit": String(min(limit, 50))])
        return page.items.compactMap { $0.album.artwork }
    }

    func topTracks(timeRange: String, limit: Int) async throws -> [ArtworkItem] {
        let page: PagedDTO<TrackDTO> = try await get("me/top/tracks",
                                                      ["time_range": timeRange, "limit": String(min(limit, 50))])
        return page.items.compactMap { $0.artwork }
    }

    func topArtists(timeRange: String, limit: Int) async throws -> [ArtworkItem] {
        let page: PagedDTO<ArtistDTO> = try await get("me/top/artists",
                                                       ["time_range": timeRange, "limit": String(min(limit, 50))])
        return page.items.compactMap { $0.artwork }
    }

    // MARK: - Playback control (requires Spotify Premium and an active device)

    func setPlayback(play: Bool) async throws {
        _ = try await send("PUT", play ? "me/player/play" : "me/player/pause")
    }

    func skip(next: Bool) async throws {
        _ = try await send("POST", next ? "me/player/next" : "me/player/previous")
    }
}

// MARK: - DTOs

private struct PagedDTO<T: Decodable>: Decodable { let items: [T] }

private struct ImageDTO: Decodable { let url: URL; let width: Int? }
private struct NamedDTO: Decodable { let name: String }

private func pickImages(_ images: [ImageDTO]?) -> (large: URL?, thumb: URL?) {
    let sorted = (images ?? []).sorted { ($0.width ?? 0) > ($1.width ?? 0) }
    let thumb = sorted.last(where: { ($0.width ?? 0) >= 300 }) ?? sorted.first
    return (sorted.first?.url, thumb?.url)
}

private struct AlbumDTO: Decodable {
    let id: String?
    let name: String
    let uri: String?
    let images: [ImageDTO]?
    let artists: [NamedDTO]?

    var artwork: ArtworkItem? {
        let img = pickImages(images)
        return ArtworkItem(
            id: id ?? uri ?? name,
            title: name,
            subtitle: (artists ?? []).map(\.name).joined(separator: ", "),
            imageURL: img.large, thumbURL: img.thumb, uri: uri
        )
    }
}

private struct TrackDTO: Decodable {
    let id: String?
    let name: String
    let uri: String?
    let durationMs: Int?
    let artists: [NamedDTO]?
    let album: AlbumDTO?
    let images: [ImageDTO]?   // podcast episodes carry images directly
    let show: NamedDTO?

    var artwork: ArtworkItem? {
        let img = pickImages(album?.images ?? images)
        let by = (artists ?? []).map(\.name).joined(separator: ", ")
        return ArtworkItem(
            id: id ?? uri ?? name,
            title: name,
            subtitle: by.isEmpty ? (show?.name ?? "") : by,
            imageURL: img.large, thumbURL: img.thumb, uri: uri
        )
    }
}

private struct ArtistDTO: Decodable {
    let id: String?
    let name: String
    let uri: String?
    let images: [ImageDTO]?

    var artwork: ArtworkItem? {
        let img = pickImages(images)
        return ArtworkItem(id: id ?? uri ?? name, title: name, subtitle: "Artist",
                           imageURL: img.large, thumbURL: img.thumb, uri: uri)
    }
}

private struct PlayerDTO: Decodable {
    let isPlaying: Bool?
    let progressMs: Int?
    let item: TrackDTO?
}

private struct RecentDTO: Decodable { let track: TrackDTO }
private struct SavedAlbumDTO: Decodable { let album: AlbumDTO }
