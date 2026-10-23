import SwiftUI
import WidgetKit
import AuthenticationServices

@MainActor
final class AppModel: ObservableObject {
    @Published var isSignedIn = TokenStore.load() != nil
    @Published var displayName: String?
    @Published var nowPlaying: PlaybackState?
    @Published var errorMessage: String?
    @Published var isBusy = false

    @Published var customClientID = ClientIDStore.load() ?? ""

    private var pollTask: Task<Void, Never>?
    private var lastSignature = ""

    init() {
        if isSignedIn { didSignIn() }
    }

    // MARK: - Sign in / out

    /// `authenticate` presents Spotify's login page and returns the callback URL
    /// (supplied by the view, which owns the `webAuthenticationSession` environment value).
    func signIn(authenticate: (URL) async throws -> URL) async {
        guard AppConfig.isConfigured else {
            errorMessage = "Add your Spotify Client ID first (see “Set up your Spotify app”)."
            return
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        let verifier = SpotifyAuth.makeVerifier()
        let state = UUID().uuidString
        let url = SpotifyAuth.authorizeURL(challenge: SpotifyAuth.challenge(for: verifier), state: state)

        do {
            let callback = try await authenticate(url)
            let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if let err = items.first(where: { $0.name == "error" })?.value {
                throw SpotifyError.authFailed("Spotify sign-in failed: \(err)")
            }
            guard items.first(where: { $0.name == "state" })?.value == state,
                  let code = items.first(where: { $0.name == "code" })?.value
            else { throw SpotifyError.authFailed("Sign-in response was invalid.") }

            let tokens = try await SpotifyAuth.exchange(code: code, verifier: verifier)
            TokenStore.save(tokens)
            isSignedIn = true
            didSignIn()
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Saves (or clears, when empty) the user's own Spotify app Client ID. Tokens belong to one app, so sign out first.
    func saveClientID(_ raw: String) {
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id != customClientID else { return }
        signOut()
        if id.isEmpty { ClientIDStore.clear() } else { ClientIDStore.save(id) }
        customClientID = id
        errorMessage = nil
        objectWillChange.send()
    }

    func signOut() {
        TokenStore.clear()
        pollTask?.cancel()
        isSignedIn = false
        displayName = nil
        nowPlaying = nil
        lastSignature = ""
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func didSignIn() {
        WidgetCenter.shared.reloadAllTimelines()
        Task { displayName = try? await SpotifyClient.shared.displayName() }
        startPolling()
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private func poll() async {
        do {
            let pb = try await SpotifyClient.shared.playback()
            nowPlaying = pb
            let signature = "\(pb?.item.id ?? "-")|\(pb?.isPlaying ?? false)"
            if signature != lastSignature {
                lastSignature = signature
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch SpotifyError.signedOut {
            signOut()
        } catch {
            // Transient network / rate-limit errors: try again on the next tick.
        }
    }
}
