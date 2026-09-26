import Foundation
import UIKit
import Combine
import SpotifyiOS

@MainActor final class SpotifyRemote: NSObject, ObservableObject, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    @Published private(set) var isConnected = false
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var errorMessage: String?
    var onTrackStarted: ((String) -> Void)?
    var onTrackEnded: (() -> Void)?

    private let clientID = Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT_ID") as? String ?? ""
    private let redirectURL = URL(string: Bundle.main.object(forInfoDictionaryKey: "APP_REMOTE_REDIRECT_URI") as? String ?? "app.vibemusic.ios://spotify-login-callback")!
    private lazy var configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
    private lazy var remote: SPTAppRemote = {
        let value = SPTAppRemote(configuration: configuration, logLevel: .error)
        value.delegate = self
        return value
    }()
    private var lastTrackURI: String?
    private var didFinishCurrentTrack = false

    func authorizeAndPlay(_ uri: String) {
        lastTrackURI = uri
        remote.authorizeAndPlayURI(uri, completionHandler: { success in if !success { Task { @MainActor in self.errorMessage = "Install Spotify to start playback." } } })
    }

    func handle(_ url: URL) {
        guard url.host == "spotify-login-callback" else { return }
        let parameters = remote.authorizationParameters(from: url)
        if let token = parameters?[SPTAppRemoteAccessTokenKey] as? String {
            remote.connectionParameters.accessToken = token
            if !remote.isConnected { remote.connect() }
        } else if let description = parameters?[SPTAppRemoteErrorDescriptionKey] as? String {
            errorMessage = description
        }
    }

    func resumeConnection() { if remote.connectionParameters.accessToken != nil && !remote.isConnected { remote.connect() } }
    func disconnect() { if remote.isConnected { remote.disconnect() }; UIApplication.shared.isIdleTimerDisabled = false }
    func togglePlayback() {
        guard let player = remote.playerAPI else { return }
        if isPlaying { player.pause(nil) } else { player.resume(nil) }
    }
    func play(_ uri: String) { lastTrackURI = uri; didFinishCurrentTrack = false; remote.playerAPI?.play(uri, callback: { _, error in if let error { Task { @MainActor in self.errorMessage = error.localizedDescription } } }) }

    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        isConnected = true
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { _, error in
            if let error { Task { @MainActor in self.errorMessage = error.localizedDescription } }
        })
    }
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) { isConnected = false; if let error { errorMessage = error.localizedDescription } }
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) { isConnected = false; errorMessage = error?.localizedDescription ?? "Could not connect to Spotify." }

    func playerStateDidChange(_ state: SPTAppRemotePlayerState) {
        let uri = state.track.uri
        let changed = uri != lastTrackURI
        if changed { lastTrackURI = uri; didFinishCurrentTrack = false }
        isPlaying = !state.isPaused
        position = Double(state.playbackPosition) / 1000
        duration = Double(state.track.duration) / 1000
        if isPlaying && !uri.isEmpty { onTrackStarted?(uri) }
        if !didFinishCurrentTrack && duration > 0 && position >= duration - 1.2 {
            didFinishCurrentTrack = true
            onTrackEnded?()
        }
    }
}
