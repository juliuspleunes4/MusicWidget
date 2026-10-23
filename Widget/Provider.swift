import WidgetKit
import Foundation

struct NowPlayingCard {
    let title: String
    let artist: String
    let album: String
    let art: Data?
    let isPlaying: Bool
    let duration: TimeInterval
    let progress: TimeInterval
    let fetchedAt: Date
    let uri: String?

    /// Wall-clock window used by the self-updating progress bar.
    var start: Date { fetchedAt.addingTimeInterval(-progress) }
    var end: Date { start.addingTimeInterval(max(duration, 1)) }
    var fraction: Double { duration > 0 ? min(max(progress / duration, 0), 1) : 0 }
}

struct GridCard: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let art: Data?
    let uri: String?
}

enum MusicState {
    case signedOut
    case message(String)
    case nowPlaying(NowPlayingCard)
    case grid(title: String, items: [GridCard])
}

struct MusicEntry: TimelineEntry {
    let date: Date
    let state: MusicState
    let style: WidgetStyle

    var backdropArt: Data? {
        if style.artworkBackdrop, case .nowPlaying(let card) = state { return card.art }
        return nil
    }

    static let placeholder = MusicEntry(
        date: .now,
        state: .nowPlaying(NowPlayingCard(title: "Song Title", artist: "Artist Name", album: "Album Name", art: nil,
                                          isPlaying: true, duration: 200, progress: 60, fetchedAt: .now, uri: nil)),
        style: WidgetStyle()
    )
}

struct MusicProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MusicEntry { .placeholder }

    func snapshot(for configuration: WidgetConfigIntent, in context: Context) async -> MusicEntry {
        if context.isPreview { return .placeholder }
        return await load(configuration, family: context.family).0
    }

    func timeline(for configuration: WidgetConfigIntent, in context: Context) async -> Timeline<MusicEntry> {
        let (entry, next) = await load(configuration, family: context.family)
        return Timeline(entries: [entry], policy: .after(next))
    }

    // MARK: - Loading

    private func load(_ config: WidgetConfigIntent, family: WidgetFamily) async -> (MusicEntry, Date) {
        let now = Date()
        func entry(_ state: MusicState) -> MusicEntry {
            MusicEntry(date: now, state: state, style: config.style)
        }

        guard TokenStore.load() != nil else { return (entry(.signedOut), now.addingTimeInterval(900)) }

        do {
            let client = SpotifyClient.shared
            switch config.content {
            case .nowPlaying:
                guard let pb = try await client.playback() else {
                    return (entry(.message("Nothing playing")), now.addingTimeInterval(300))
                }
                let art = await ImageLoader.jpeg(from: pb.item.imageURL, maxPixel: family == .systemSmall ? 500 : 800)
                let card = NowPlayingCard(
                    title: pb.item.title, artist: pb.item.subtitle, album: pb.album, art: art,
                    isPlaying: pb.isPlaying,
                    duration: Double(pb.durationMs) / 1000, progress: Double(pb.progressMs) / 1000,
                    fetchedAt: pb.fetchedAt, uri: pb.item.uri
                )
                // Refresh when the track should end (clamped); WidgetKit may delay this to protect its budget.
                let remaining = Double(pb.durationMs - pb.progressMs) / 1000 + 1
                let next = pb.isPlaying ? now.addingTimeInterval(min(max(remaining, 20), 300))
                                        : now.addingTimeInterval(600)
                return (entry(.nowPlaying(card)), next)

            case .recentAlbums:
                let items = try await client.recentAlbums(limit: gridLimit(family))
                return (entry(await grid("Recently Played", items)), now.addingTimeInterval(900))
            case .savedAlbums:
                let items = try await client.savedAlbums(limit: gridLimit(family))
                return (entry(await grid("Saved Albums", items)), now.addingTimeInterval(3600))
            case .topTracks:
                let items = try await client.topTracks(timeRange: config.timeRange.rawValue, limit: gridLimit(family))
                return (entry(await grid("Top Tracks", items)), now.addingTimeInterval(3600))
            case .topArtists:
                let items = try await client.topArtists(timeRange: config.timeRange.rawValue, limit: gridLimit(family))
                return (entry(await grid("Top Artists", items)), now.addingTimeInterval(3600))
            }
        } catch SpotifyError.signedOut {
            return (entry(.signedOut), now.addingTimeInterval(900))
        } catch {
            return (entry(.message("Couldn't reach Spotify")), now.addingTimeInterval(300))
        }
    }

    private func gridLimit(_ family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 4
        case .systemMedium: return 8
        case .systemLarge: return 12
        default: return 24
        }
    }

    private func grid(_ title: String, _ items: [ArtworkItem]) async -> MusicState {
        if items.isEmpty { return .message("Nothing to show yet") }
        let images = await withTaskGroup(of: (Int, Data?).self) { group -> [Data?] in
            for (i, item) in items.enumerated() {
                group.addTask { (i, await ImageLoader.jpeg(from: item.thumbURL, maxPixel: 320)) }
            }
            var out = [Data?](repeating: nil, count: items.count)
            for await (i, data) in group { out[i] = data }
            return out
        }
        let cards = items.enumerated().map { i, item in
            GridCard(id: item.id, title: item.title, subtitle: item.subtitle, art: images[i], uri: item.uri)
        }
        return .grid(title: title, items: cards)
    }
}
