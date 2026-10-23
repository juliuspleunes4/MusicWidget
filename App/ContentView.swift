import SwiftUI
import AuthenticationServices
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showSetup = !AppConfig.isConfigured
    @State private var clientIDField = ""

    var body: some View {
        ScrollView { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if model.isSignedIn {
                signedIn
            } else {
                signedOut
            }

            if let error = model.errorMessage {
                Text(error).font(.callout).foregroundStyle(.red)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.house.fill").font(.system(size: 34)).foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text("Music Widget").font(.title2.bold())
                Text("Spotify on your desktop").foregroundStyle(.secondary)
            }
        }
    }

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect your Spotify account to power the widgets.")
            Button {
                Task {
                    await model.signIn { url in
                        try await webAuth.authenticate(using: url, callbackURLScheme: AppConfig.redirectScheme)
                    }
                }
            } label: {
                Label("Connect Spotify", systemImage: "link")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.green)
            .disabled(model.isBusy || !AppConfig.isConfigured)

            setupGuide
        }
    }

    /// Spotify limits how many people one developer app can serve, so each user connects through their own free app.
    private var setupGuide: some View {
        DisclosureGroup("Set up your Spotify app", isExpanded: $showSetup) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Spotify only lets a few people use any one developer app, so you connect with your own. It takes about two minutes and is free (Spotify requires Premium to create one).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("1. Open the")
                        Link("Spotify Developer Dashboard", destination: URL(string: "https://developer.spotify.com/dashboard")!)
                        Text("and click **Create app**.")
                    }
                    HStack(spacing: 6) {
                        Text("2. Set the Redirect URI to")
                        Text(AppConfig.redirectURI).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(AppConfig.redirectURI, forType: .string)
                        }
                        .controlSize(.small)
                    }
                    Text("3. Tick **Web API**, agree to the terms, and save.")
                    Text("4. Open the app’s **Settings**, copy the **Client ID**, and paste it here:")
                }
                .font(.callout)
                HStack {
                    TextField("Client ID", text: $clientIDField)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("Save") { model.saveClientID(clientIDField) }
                        .disabled(clientIDField.trimmingCharacters(in: .whitespaces) == model.customClientID)
                }
                if !model.customClientID.isEmpty {
                    Text("Using your own Spotify app. Clear the field and save to go back to the built-in one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        }
        .onAppear { clientIDField = model.customClientID }
    }

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Connected as \(model.displayName ?? "Spotify user")", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

            GroupBox("Now playing") {
                Group {
                    if let pb = model.nowPlaying {
                        VStack(alignment: .leading) {
                            Text(pb.item.title).font(.headline)
                            Text(pb.item.subtitle).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Nothing playing right now").foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox("Add the widget") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Right-click your desktop → **Edit Widgets…**")
                    Text("2. Search for **Music Widget** and pick a size.")
                    Text("3. Right-click the widget → **Edit “Music Widget”** to choose what it shows: Now Playing, Recent Albums, Saved Albums, Top Tracks or Top Artists.")
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox("Themes") {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                        ForEach(ThemeOption.allCases, id: \.self) { ThemeSwatch(theme: $0) }
                    }
                    Text("Pick a theme per widget: right-click it → Edit “Music”. You can also change the accent color, artwork corners, and turn on a blurred-artwork background.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            }

            Toggle("Launch at login (keeps widgets live)", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        model.errorMessage = error.localizedDescription
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Button("Disconnect Spotify", role: .destructive) { model.signOut() }
        }
    }
}

private struct ThemeSwatch: View {
    let theme: ThemeOption

    var body: some View {
        let p = ThemePalette.make(theme: theme, accent: .themeDefault)
        VStack(spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                p.backgroundView
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aa").font(.headline).foregroundStyle(p.text)
                    Capsule().fill(p.accent).frame(width: 26, height: 4)
                }
                .padding(8)
            }
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.quaternary))
            Text(theme.label).font(.caption2)
        }
    }
}
