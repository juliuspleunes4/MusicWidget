# Music Widget for macOS

Native desktop widgets for Spotify, built with SwiftUI + WidgetKit (macOS 14 Sonoma or later).

**Widget sizes:** small, medium, large and extra-large. Layouts adapt to each size.

**What a widget can show** (right-click the widget → *Edit "Music"*):

| Option | What you get |
|---|---|
| Now Playing | Artwork, title, artist, live progress bar, and ⏮ ⏯ ⏭ buttons (medium and up) |
| Recently Played Albums | Grid of covers from your listening history |
| Saved Albums | Grid of albums in your library |
| Top Tracks / Top Artists | Choose last 4 weeks, 6 months or all time |

Each option can be placed more than once, so you can have a Now Playing widget and an album wall side by side.

**Customizing** (same Edit dialog, every widget has its own settings):

| Setting | Choices |
|---|---|
| Theme | Automatic (follows macOS), Light, Dark, Ultra Dark (pure black), Midnight, Ocean, Forest, Sunset, Rose, Lavender |
| Accent Color | Theme default, Spotify green, white, red, orange, yellow, blue, purple, pink |
| Artwork Corners | Sharp, Soft, Round |
| Blurred Artwork Background | Off by default; for Now Playing, replaces the theme background with the blurred cover |

The app window shows a preview of every theme. To add your own theme, add a case in `Shared/Theme.swift`.

Playback buttons need **Spotify Premium** and an active Spotify device.

## Layout

```
project.yml          XcodeGen spec (generates the .xcodeproj, entitlements and Info.plists)
Shared/              Spotify OAuth (PKCE), API client, keychain, image loader (used by app + widget)
App/                 Host app: sign-in window, menu-bar item, keeps widgets fresh
Widget/              WidgetKit extension: provider, configuration intent, views, button intents
```

The app signs in once and saves the tokens to a keychain group shared with the widget. The widget calls Spotify itself.

## Setup (on a Mac with Xcode 15+)

1. **Create a Spotify app** at <https://developer.spotify.com/dashboard>.
   - Redirect URI: `musicwidget://callback`
   - APIs used: Web API
   - Under *User Management*, add your Spotify account email (development-mode apps only work for listed users).
2. **Edit the config**
   - `Shared/Config.swift`: paste your Client ID. No secret is needed.
   - `project.yml`: set `BUNDLE_ID_BASE` (e.g. `com.yourname.MusicWidget`) and `DEVELOPMENT_TEAM` (your Team ID).
3. **Generate and open the project**
   ```bash
   brew install xcodegen
   xcodegen generate
   open MusicWidget.xcodeproj
   ```
4. Select the **MusicWidget** scheme, then **Run**. Click **Connect Spotify**.
5. Right-click the desktop → **Edit Widgets…** → **Music Widget**. Drag it onto the desktop.

If the widget doesn't appear, run the app once from `/Applications` and sign out and in again. macOS registers widget extensions when the host app launches.

## Distributing it

Archive in Xcode (**Product → Archive**), then **Distribute App → Direct Distribution (Developer ID)**. Xcode signs, notarizes and staples it. Put the result in a `.dmg` or `.zip`.

For the Mac App Store, choose **App Store Connect** and add an app icon first.

## Limitations

- **WidgetKit controls refresh timing, not the app.** Widgets get a limited number of refreshes per day, so Now Playing can lag a few seconds to a few minutes. The progress bar animates on its own. While the menu-bar app runs (enable *Launch at login*), it asks widgets to reload within about 10 seconds of a track or play/pause change.
- **Spotify quota.** Development-mode apps allow about 25 allow-listed users. A public release needs Spotify's extended-access approval, which they currently grant only to established organizations. That makes this best suited to personal use or a small group.
- **Token refresh.** The app and the widget share one refresh token. If Spotify ever rotates it at the same moment in both, one sign-in may be lost and you reconnect from the app.
- **Not yet compiled.** This code was written on Windows without Xcode, so expect to fix a few compiler errors on the first build.

## Building without a Mac

Apple's compiler only runs on macOS, so there are two routes:

1. **A Mac with Xcode 15+ (the setup steps above).** Open this folder in Claude Code on that Mac and ask it to build and fix any errors. It can run `xcodebuild` itself and iterate until it passes.
2. **GitHub Actions (no Mac needed to find compile errors).** `.github/workflows/build.yml` builds the project on a GitHub-hosted Mac. Push this folder to a GitHub repo, open the **Actions** tab, and read the build log. Paste any errors back into Claude to fix. This only compiles; to run and sign the app you still need a Mac, since the signing certificate and Gatekeeper checks happen there.
