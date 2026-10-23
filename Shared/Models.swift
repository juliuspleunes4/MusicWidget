import Foundation

/// One piece of artwork-backed content: an album, a track, or an artist.
struct ArtworkItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let imageURL: URL?   // largest available (~640px)
    let thumbURL: URL?   // ~300px, used for grids
    let uri: String?     // spotify:album:… — opens in the Spotify app
}

struct PlaybackState: Sendable {
    let item: ArtworkItem
    let album: String
    let durationMs: Int
    let progressMs: Int
    let isPlaying: Bool
    let fetchedAt: Date
}
