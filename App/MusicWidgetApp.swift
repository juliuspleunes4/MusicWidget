import SwiftUI

@main
struct MusicWidgetApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Music Widget", id: "main") {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // Keeps the app alive in the menu bar so it can nudge the widgets when the track changes.
        MenuBarExtra("Music Widget", systemImage: "music.note") {
            MenuBarContent().environmentObject(model)
        }
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let pb = model.nowPlaying {
            Text("\(pb.item.title) — \(pb.item.subtitle)")
        } else {
            Text(model.isSignedIn ? "Nothing playing" : "Not signed in")
        }
        Divider()
        Button("Open Music Widget") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
