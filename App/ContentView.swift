import SwiftUI
import AuthenticationServices
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Group {
            if model.isSignedIn {
                SignedInView(launchAtLogin: $launchAtLogin)
                    .frame(height: 680)
            } else {
                SignedOutView()
            }
        }
        .frame(width: 460)
        .background { AmbientBackground(artworkURL: model.nowPlaying?.item.imageURL) }
        .animation(.smooth, value: model.isSignedIn)
    }
}

// MARK: - Liquid Glass helpers (macOS 26+, with a frosted-material fallback)

private extension View {
    @ViewBuilder func glassCard(cornerRadius: CGFloat = 22) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        #else
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        #endif
    }

    @ViewBuilder func primaryButtonStyle() -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
        #else
        self.buttonStyle(.borderedProminent)
        #endif
    }
}

/// Soft colour behind the glass so it has something to refract: the current album art, or a gentle gradient.
private struct AmbientBackground: View {
    let artworkURL: URL?

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if let artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image.resizable().scaledToFill().blur(radius: 70).saturation(1.4).opacity(0.5)
                } placeholder: { Color.clear }
            } else {
                Circle().fill(Color.green.opacity(0.28)).frame(width: 340).blur(radius: 80).offset(x: -130, y: -220)
                Circle().fill(Color.purple.opacity(0.24)).frame(width: 380).blur(radius: 90).offset(x: 150, y: 240)
            }
        }
        .clipped()
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.7), value: artworkURL)
    }
}

// MARK: - Signed out

private struct SignedOutView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.webAuthenticationSession) private var webAuth

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "waveform")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 104, height: 104)
                .background(
                    LinearGradient(colors: [Color(red: 0.12, green: 0.84, blue: 0.38), Color(red: 0.0, green: 0.55, blue: 0.55)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                )
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)

            VStack(spacing: 6) {
                Text("Music Widget").font(.largeTitle.bold())
                Text("Your Spotify, right on your desktop.").foregroundStyle(.secondary)
            }

            Button {
                Task {
                    await model.signIn { url in
                        try await webAuth.authenticate(using: url, callbackURLScheme: AppConfig.redirectScheme)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if model.isBusy { ProgressView().controlSize(.small) }
                    Text("Connect Spotify").fontWeight(.semibold)
                }
                .frame(minWidth: 170)
            }
            .primaryButtonStyle()
            .controlSize(.large)
            .tint(.green)
            .disabled(model.isBusy)

            if let error = model.errorMessage {
                Text(error).font(.callout).foregroundStyle(.red).multilineTextAlignment(.center)
            }

            Text("You sign in on Spotify’s own page. Music Widget never sees your password.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 64)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Signed in

private struct SignedInView: View {
    @EnvironmentObject var model: AppModel
    @Binding var launchAtLogin: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                nowPlaying

                group("Add a widget") {
                    VStack(alignment: .leading, spacing: 14) {
                        step("cursorarrow.click.2", "Right-click your desktop and choose **Edit Widgets…**")
                        step("magnifyingglass", "Search for **Music Widget** and pick a size.")
                        step("slider.horizontal.3", "Right-click the widget and choose **Edit “Music”** to change what it shows and how it looks.")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                }

                group("Appearance") {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Theme").font(.subheadline.weight(.medium))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 12)], spacing: 14) {
                                ForEach(ThemeOption.concrete, id: \.self) { theme in
                                    ThemeSwatch(theme: theme, isSelected: model.style.theme == theme)
                                        .onTapGesture { model.updateStyle { $0.theme = theme } }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Accent color").font(.subheadline.weight(.medium))
                            HStack(spacing: 12) {
                                ForEach(AccentOption.concrete, id: \.self) { accent in
                                    AccentDot(accent: accent, theme: model.style.theme, isSelected: model.style.accent == accent)
                                        .onTapGesture { model.updateStyle { $0.accent = accent } }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Artwork corners").font(.subheadline.weight(.medium))
                            Picker("Artwork corners", selection: Binding(
                                get: { model.style.corners },
                                set: { corners in model.updateStyle { $0.corners = corners } }
                            )) {
                                ForEach(CornerOption.concrete, id: \.self) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        Text("Applies to every widget. To give one widget its own look, right-click it and choose Edit “Music”.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                }

                group("General") {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Open at login")
                            Spacer()
                            Toggle("Open at login", isOn: $launchAtLogin)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                        .padding(.vertical, 12)
                        Divider()
                        HStack {
                            Label("Connected as \(model.displayName ?? "Spotify user")", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                            Spacer()
                            Button("Disconnect", role: .destructive) { model.signOut() }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 18)
                    .glassCard()
                }

                if let error = model.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 40)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
        .onChange(of: launchAtLogin) { _, enabled in
            do {
                if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                model.errorMessage = error.localizedDescription
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private var nowPlaying: some View {
        HStack(spacing: 16) {
            AsyncImage(url: model.nowPlaying?.item.thumbURL ?? model.nowPlaying?.item.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "music.note").font(.title).foregroundStyle(.secondary)
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                if let pb = model.nowPlaying {
                    Text(pb.isPlaying ? "NOW PLAYING" : "PAUSED")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                    Text(pb.item.title).font(.title3.weight(.semibold)).lineLimit(1)
                    Text(pb.item.subtitle).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text("Nothing playing").font(.title3.weight(.semibold))
                    Text("Play something in Spotify.").foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(cornerRadius: 26)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).padding(.leading, 6)
            content()
        }
    }

    private func step(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.green)
                .frame(width: 22)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
    }
}

private struct ThemeSwatch: View {
    let theme: ThemeOption
    let isSelected: Bool

    var body: some View {
        let p = ThemePalette.make(theme: theme, accent: .themeDefault)
        VStack(spacing: 5) {
            ZStack(alignment: .bottomLeading) {
                p.backgroundView
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aa").font(.headline).foregroundStyle(p.text)
                    Capsule().fill(p.accent).frame(width: 24, height: 4)
                }
                .padding(8)
            }
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 3 : 1)
            )
            Text(theme.label)
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct AccentDot: View {
    let accent: AccentOption
    let theme: ThemeOption
    let isSelected: Bool

    var body: some View {
        let color = accent.color ?? ThemePalette.make(theme: theme, accent: .themeDefault).accent
        ZStack {
            Circle().fill(color)
            if accent == .themeDefault {
                Image(systemName: "wand.and.stars").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(width: 26, height: 26)
        .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
        .padding(3)
        .overlay(Circle().stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2.5))
        .contentShape(Circle())
        .accessibilityLabel(Text(accent == .themeDefault ? "Theme default" : accent.rawValue.capitalized))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
