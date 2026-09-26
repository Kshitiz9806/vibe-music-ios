import Foundation
import Combine

@MainActor final class RadioViewModel: ObservableObject {
    @Published var genres: [String] = []
    @Published var selectedGenres = Set<String>()
    @Published var selectedArtists: [PickerItem] = []
    @Published var selectedAlbums: [PickerItem] = []
    @Published var searchText = ""
    @Published var searchType = "artist"
    @Published var searchResults: [PickerItem] = []
    @Published var radioSessionID: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var duration: Double = 0
    let session: SessionStore
    let remote: SpotifyRemote
    private var reservations: [String: String] = [:]

    init(session: SessionStore, remote: SpotifyRemote) {
        self.session = session; self.remote = remote
        remote.onTrackStarted = { [weak self] uri in Task { await self?.markStarted(uri) } }
        remote.onTrackEnded = { [weak self] in Task { await self?.playNext() } }
    }
    var selectionCount: Int { selectedGenres.count + selectedArtists.count + selectedAlbums.count }
    var canAddSelection: Bool { selectionCount < 5 }
    var parameters: RadioParameters { RadioParameters(genres: Array(selectedGenres).sorted(), artistIds: selectedArtists.map(\.id), albumIds: selectedAlbums.map(\.id)) }

    func loadGenres() async {
        guard let token = session.token else { return }
        do { let response: GenreResponse = try await APIClient.shared.request("/radio/genres", token: token); genres = response.genres }
        catch { errorMessage = error.localizedDescription }
    }
    func search() async {
        guard let token = session.token, !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { searchResults = []; return }
        do { let response: PickerResults = try await APIClient.shared.request(searchPath, token: token); searchResults = response.items }
        catch { errorMessage = error.localizedDescription }
    }
    private var searchPath: String {
        var c = URLComponents(); c.path = "/radio/search"; c.queryItems = [.init(name: "q", value: searchText), .init(name: "type", value: searchType)]
        return c.string ?? "/radio/search"
    }
    func toggleGenre(_ genre: String) { if selectedGenres.contains(genre) { selectedGenres.remove(genre) } else if canAddSelection { selectedGenres.insert(genre) } }
    func add(_ item: PickerItem) { guard canAddSelection else { return }; if searchType == "artist", !selectedArtists.contains(item) { selectedArtists.append(item) }; if searchType == "album", !selectedAlbums.contains(item) { selectedAlbums.append(item) } }
    func remove(_ item: PickerItem) { selectedArtists.removeAll { $0.id == item.id }; selectedAlbums.removeAll { $0.id == item.id } }

    func startRadio() async {
        guard let token = session.token else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let radio: RadioResponse = try await APIClient.shared.request("/radio/start", method: "POST", body: parameters, token: token)
            radioSessionID = radio.radioSessionId
            let track = try await nextTrack()
            reservations[track.trackUri] = track.playHistoryId
            remote.authorizeAndPlay(track.trackUri)
        } catch { errorMessage = error.localizedDescription; radioSessionID = nil }
    }
    func playNext() async {
        guard remote.isConnected else { return }
        do { let track = try await nextTrack(); reservations[track.trackUri] = track.playHistoryId; remote.play(track.trackUri) }
        catch { errorMessage = error.localizedDescription }
    }
    private func nextTrack() async throws -> TrackResponse {
        guard let token = session.token, let id = radioSessionID else { throw APIError.unauthorized }
        return try await APIClient.shared.request("/radio/\(id)/next-track", token: token)
    }
    private func markStarted(_ uri: String) async {
        guard let playHistoryId = reservations.removeValue(forKey: uri), let token = session.token, let id = radioSessionID else { return }
        struct Played: Encodable { let playHistoryId: String; let playedAt: Date }
        do { try await APIClient.shared.noContent("/radio/\(id)/mark-played", method: "POST", body: Played(playHistoryId: playHistoryId, playedAt: Date()), token: token) }
        catch { errorMessage = error.localizedDescription }
    }
    func endRadio() async {
        if let token = session.token, let id = radioSessionID { try? await APIClient.shared.noContent("/radio/\(id)/end", method: "POST", token: token) }
        remote.disconnect(); radioSessionID = nil
    }
}
