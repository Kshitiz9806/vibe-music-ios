import SwiftUI

@main struct VibeMusicApp: App {
    @StateObject private var session: SessionStore
    @StateObject private var remote: SpotifyRemote
    @StateObject private var radio: RadioViewModel
    @StateObject private var backend = BackendReadiness()
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
                if !backend.isReady {
                    BackendStartupView(state: backend.state, retry: { Task { await backend.checkUntilReady() } })
                }
                else if session.token == nil { SignInView(login: login) { session.save($0) } }
                else if radio.radioSessionID != nil {
                    PlayerView(
                        model: radio,
                        remote: remote,
                        restart: { Task { await radio.restartRadio() } },
                        end: { Task { await radio.endRadio() } }
                    )
                }
                else { LandingView(model: radio, start: { parameters in Task { await radio.startRadio(using: parameters) } }, signOut: { Task { await session.signOut() } }) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onOpenURL { remote.handle($0) }
            .task {
                await backend.checkUntilReady()
                await session.restore()
            }
            .preferredColorScheme(.dark)
        }
    }
}
