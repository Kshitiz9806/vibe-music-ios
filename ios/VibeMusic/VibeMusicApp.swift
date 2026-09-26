import SwiftUI

@main struct VibeMusicApp: App {
    @StateObject private var session: SessionStore
    @StateObject private var remote: SpotifyRemote
    @StateObject private var radio: RadioViewModel
    private let login = SpotifyLogin()

    init() {
        let session = SessionStore(); let remote = SpotifyRemote()
        _session = StateObject(wrappedValue: session)
        _remote = StateObject(wrappedValue: remote)
        _radio = StateObject(wrappedValue: RadioViewModel(session: session, remote: remote))
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if session.token == nil { SignInView(login: login) { session.save($0) } }
                else if radio.radioSessionID != nil { PlayerView(model: radio, remote: remote) { Task { await radio.endRadio() } } }
                else { LandingView(model: radio, start: { Task { await radio.startRadio() } }, signOut: { Task { await session.signOut() } }) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onOpenURL { remote.handle($0) }
            .task { await session.restore() }
            .preferredColorScheme(.dark)
        }
    }
}
