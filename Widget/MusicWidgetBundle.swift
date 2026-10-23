import WidgetKit
import SwiftUI

@main
struct MusicWidgetBundle: WidgetBundle {
    var body: some Widget {
        MusicWidget()
    }
}

struct MusicWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: AppConfig.widgetKind, intent: WidgetConfigIntent.self, provider: MusicProvider()) { entry in
            MusicWidgetView(entry: entry)
        }
        .configurationDisplayName("Music")
        .description("Now playing, recent albums, saved albums, top tracks and top artists from Spotify.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}
