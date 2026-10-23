import AppIntents
import WidgetKit

enum ContentKind: String, AppEnum {
    case nowPlaying, recentAlbums, savedAlbums, topTracks, topArtists

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Content"
    static var caseDisplayRepresentations: [ContentKind: DisplayRepresentation] = [
        .nowPlaying: "Now Playing",
        .recentAlbums: "Recently Played Albums",
        .savedAlbums: "Saved Albums",
        .topTracks: "Top Tracks",
        .topArtists: "Top Artists",
    ]
}

enum TimeRange: String, AppEnum {
    case short = "short_term"
    case medium = "medium_term"
    case long = "long_term"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Time Range"
    static var caseDisplayRepresentations: [TimeRange: DisplayRepresentation] = [
        .short: "Last 4 weeks",
        .medium: "Last 6 months",
        .long: "All time",
    ]
}

struct WidgetConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Music Widget"
    static var description = IntentDescription("Choose what this widget shows.")

    @Parameter(title: "Show", default: .nowPlaying)
    var content: ContentKind

    @Parameter(title: "Time Range (Top Tracks / Artists)", default: .medium)
    var timeRange: TimeRange

    @Parameter(title: "Theme", default: .system)
    var theme: ThemeOption

    @Parameter(title: "Accent Color", default: .themeDefault)
    var accent: AccentOption

    @Parameter(title: "Artwork Corners", default: .soft)
    var corners: CornerOption

    @Parameter(title: "Blurred Artwork Background (Now Playing)", default: false)
    var artworkBackdrop: Bool

    var style: WidgetStyle {
        WidgetStyle(theme: theme, accent: accent, corners: corners, artworkBackdrop: artworkBackdrop)
    }

    init() {}
}

// MARK: - Interactive playback buttons (Spotify Premium + an active device required)

struct PlaybackIntent: AppIntent {
    static var title: LocalizedStringResource = "Play or Pause"
    static var isDiscoverable = false

    @Parameter(title: "Play")
    var play: Bool

    init() {}
    init(play: Bool) { self.play = play }

    func perform() async throws -> some IntentResult {
        try? await SpotifyClient.shared.setPlayback(play: play)
        try? await Task.sleep(for: .milliseconds(700))
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SkipIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Track"
    static var isDiscoverable = false

    @Parameter(title: "Next")
    var next: Bool

    init() {}
    init(next: Bool) { self.next = next }

    func perform() async throws -> some IntentResult {
        try? await SpotifyClient.shared.skip(next: next)
        try? await Task.sleep(for: .milliseconds(900))
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
