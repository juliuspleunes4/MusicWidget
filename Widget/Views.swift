import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Theme plumbing

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.make(theme: .system, accent: .themeDefault)
}
private struct CornerScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}
private extension EnvironmentValues {
    var palette: ThemePalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
    var cornerScale: CGFloat {
        get { self[CornerScaleKey.self] }
        set { self[CornerScaleKey.self] = newValue }
    }
}

// MARK: - Root

struct MusicWidgetView: View {
    let entry: MusicEntry

    private var palette: ThemePalette {
        let base = ThemePalette.make(theme: entry.style.theme, accent: entry.style.accent)
        return entry.backdropArt != nil ? base.onDark : base
    }

    var body: some View {
        Group {
            switch entry.state {
            case .signedOut:
                MessageView(icon: "person.crop.circle.badge.exclamationmark",
                            text: "Open Music Widget and connect Spotify")
            case .message(let text):
                MessageView(icon: "music.note", text: text)
            case .nowPlaying(let card):
                NowPlayingView(card: card)
            case .grid(let title, let items):
                GridView(title: title, items: items)
            }
        }
        .environment(\.palette, palette)
        .environment(\.cornerScale, entry.style.corners.scale)
        .containerBackground(for: .widget) { background }
    }

    @ViewBuilder private var background: some View {
        if let data = entry.backdropArt, let image = NSImage(data: data) {
            ZStack {
                Image(nsImage: image).resizable().scaledToFill().blur(radius: 40).scaleEffect(1.3)
                Color.black.opacity(0.45)
            }
        } else {
            ThemePalette.make(theme: entry.style.theme, accent: entry.style.accent).backgroundView
        }
    }
}

// MARK: - Shared pieces

private extension Image {
    /// Keep album art in full colour when the desktop uses the tinted/accented widget style (macOS 15+).
    @ViewBuilder func fullColorArtwork() -> some View {
        if #available(macOS 15.0, *) { self.widgetAccentedRenderingMode(.fullColor) } else { self }
    }
}

private struct Artwork: View {
    let data: Data?
    @Environment(\.palette) private var palette

    var body: some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image).resizable().fullColorArtwork()
        } else {
            ZStack {
                LinearGradient(colors: [palette.accent.opacity(0.9), palette.accent.opacity(0.4)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

private struct MessageView: View {
    let icon: String
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title)
            Text(text).font(.footnote).multilineTextAlignment(.center)
        }
        .foregroundStyle(palette.secondary)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProgressBar: View {
    let card: NowPlayingCard
    @Environment(\.palette) private var palette

    var body: some View {
        if card.isPlaying, card.duration > 0 {
            ProgressView(timerInterval: card.start...card.end, countsDown: false,
                         label: { EmptyView() }, currentValueLabel: { EmptyView() })
                .progressViewStyle(.linear)
                .tint(palette.accent)
        } else {
            ProgressView(value: card.fraction)
                .progressViewStyle(.linear)
                .tint(palette.accent)
        }
    }
}

private struct Controls: View {
    let isPlaying: Bool
    let size: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: size * 1.3) {
            Button(intent: SkipIntent(next: false)) { Image(systemName: "backward.fill") }
            Button(intent: PlaybackIntent(play: !isPlaying)) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: size * 1.3))
                    .foregroundStyle(palette.accent)
            }
            Button(intent: SkipIntent(next: true)) { Image(systemName: "forward.fill") }
        }
        .buttonStyle(.plain)
        .font(.system(size: size))
        .foregroundStyle(palette.text)
    }
}

/// Rounded-corner clip whose radius follows the widget's "Artwork Corners" setting.
private struct ArtworkClip: ViewModifier {
    let base: CGFloat
    @Environment(\.cornerScale) private var scale

    func body(content: Content) -> some View {
        content.clipShape(RoundedRectangle(cornerRadius: base * scale, style: .continuous))
    }
}
private extension View {
    func artworkCorners(_ base: CGFloat) -> some View { modifier(ArtworkClip(base: base)) }
}

// MARK: - Now playing

private struct NowPlayingView: View {
    let card: NowPlayingCard
    @Environment(\.widgetFamily) private var family
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: WideNowPlaying(card: card, big: false)
            case .systemLarge: tall
            default: WideNowPlaying(card: card, big: true)
            }
        }
        .widgetURL(card.uri.flatMap { URL(string: $0) })
    }

    /// Small: artwork fills the widget with the title over it (always white for legibility).
    private var small: some View {
        ZStack(alignment: .bottomLeading) {
            Artwork(data: card.art)
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 1) {
                Text(card.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(card.artist).font(.caption).opacity(0.8).lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(10)
        }
    }

    private var tall: some View {
        GeometryReader { geo in
            let side = min(geo.size.width - 32, geo.size.height - 150)
            VStack(spacing: 12) {
                Artwork(data: card.art)
                    .frame(width: side, height: side)
                    .artworkCorners(14)
                    .shadow(radius: 8, y: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title).font(.title3.bold()).foregroundStyle(palette.text).lineLimit(1)
                    Text(card.artist).font(.subheadline).foregroundStyle(palette.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ProgressBar(card: card)
                Controls(isPlaying: card.isPlaying, size: 20)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct WideNowPlaying: View {
    let card: NowPlayingCard
    let big: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            let pad: CGFloat = big ? 24 : 16
            let side = geo.size.height - pad * 2
            HStack(spacing: big ? 24 : 14) {
                Artwork(data: card.art)
                    .frame(width: side, height: side)
                    .artworkCorners(big ? 16 : 10)
                    .shadow(radius: 6, y: 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.title).font(big ? Font.title.bold() : Font.headline)
                        .foregroundStyle(palette.text).lineLimit(2)
                    Text(card.artist).font(big ? Font.title3 : Font.subheadline)
                        .foregroundStyle(palette.secondary).lineLimit(1)
                    Text(card.album).font(big ? Font.body : Font.caption)
                        .foregroundStyle(palette.secondary).opacity(0.8).lineLimit(1)
                    Spacer(minLength: 4)
                    ProgressBar(card: card)
                    Controls(isPlaying: card.isPlaying, size: big ? 26 : 17)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(pad)
        }
    }
}

// MARK: - Album / track / artist grids

private struct GridView: View {
    let title: String
    let items: [GridCard]
    @Environment(\.widgetFamily) private var family
    @Environment(\.palette) private var palette

    var body: some View {
        if family == .systemSmall { mosaic } else { adaptive }
    }

    /// Small: edge-to-edge 2×2 collage; tapping opens the first item.
    private var mosaic: some View {
        GeometryReader { geo in
            let cell = geo.size.width / 2
            VStack(spacing: 0) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { col in
                            let i = row * 2 + col
                            Artwork(data: i < items.count ? items[i].art : nil)
                                .scaledToFill()
                                .frame(width: cell, height: geo.size.height / 2)
                                .clipped()
                        }
                    }
                }
            }
        }
        .widgetURL(items.first?.uri.flatMap { URL(string: $0) })
    }

    private struct Layout { var cols = 2; var rows = 1; var cell: CGFloat = 60; var caption: CGFloat = 0 }

    /// Picks the column count that shows the most items at a readable size for whatever space the widget has.
    private func bestLayout(width: CGFloat, height: CGFloat, spacing: CGFloat) -> Layout {
        var best = Layout()
        var bestScore = -1
        for cols in 2...8 {
            let cell = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            guard cell >= 56 else { break }
            let caption: CGFloat = cell >= 84 ? 30 : 0
            let rows = Int((height + spacing) / (cell + caption + spacing))
            guard rows >= 1 else { continue }
            let score = cols * rows + (caption > 0 ? 8 : 0)
            if score > bestScore {
                bestScore = score
                best = Layout(cols: cols, rows: rows, cell: cell, caption: caption)
            }
        }
        return best
    }

    private var adaptive: some View {
        GeometryReader { geo in
            let pad: CGFloat = 14
            let spacing: CGFloat = 8
            let headerHeight: CGFloat = 22
            let l = bestLayout(width: geo.size.width - pad * 2,
                               height: geo.size.height - pad * 2 - headerHeight,
                               spacing: spacing)
            VStack(alignment: .leading, spacing: spacing) {
                Text(title.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accent)
                    .frame(height: headerHeight - spacing, alignment: .leading)
                ForEach(0..<l.rows, id: \.self) { row in
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(0..<l.cols, id: \.self) { col in
                            let i = row * l.cols + col
                            if i < items.count { cell(items[i], layout: l) }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(pad)
        }
    }

    @ViewBuilder private func cell(_ item: GridCard, layout l: Layout) -> some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            Artwork(data: item.art)
                .frame(width: l.cell, height: l.cell)
                .artworkCorners(8)
            if l.caption > 0 {
                Text(item.title).font(.caption2.weight(.semibold)).foregroundStyle(palette.text).lineLimit(1)
                Text(item.subtitle).font(.caption2).foregroundStyle(palette.secondary).lineLimit(1)
            }
        }
        .frame(width: l.cell, alignment: .leading)

        if let url = item.uri.flatMap({ URL(string: $0) }) {
            Link(destination: url) { content }
        } else {
            content
        }
    }
}
