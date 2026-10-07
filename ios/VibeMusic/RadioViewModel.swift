import Foundation
import Combine

@MainActor final class RadioViewModel: ObservableObject {
    @Published var genres: [String] = []
    @Published var selectedGenres = Set<String>()
    @Published var selectedArtists: [PickerItem] = []
    @Published var selectedAlbums: [PickerItem] = []
    @Published var searchText = ""
    @Published var searchType = "artist" {
        didSet { if oldValue != searchType { searchResults = [] } }
    }
    @Published var searchResults: [PickerItem] = []
    @Published var radioSessionID: String?
    @Published var isLoadingGenres = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var duration: Double = 0
    let session: SessionStore
    let remote: SpotifyRemote
    private var reservations: [String: String] = [:]
    private var backendKeepAliveTask: Task<Void, Never>?
    private let liveActivity = RadioLiveActivityController()

    init(session: SessionStore, remote: SpotifyRemote) {
        self.session = session; self.remote = remote
        // A relaunched app has no restored radio session, so any retained
        // Live Activity belongs to a session that is no longer active here.
        liveActivity.endAllActivities()
        remote.onTrackStarted = { [weak self] uri in Task { await self?.markStarted(uri) } }
        remote.onTrackEnded = { [weak self] in Task { await self?.playNext() } }
        remote.onPlaybackChanged = { [weak self] isPlaying in self?.liveActivity.update(isPlaying: isPlaying) }
    }
    var selectionCount: Int { selectedGenres.count + selectedArtists.count + selectedAlbums.count }
    var canAddSelection: Bool { selectionCount < 5 }
    var parameters: RadioParameters { RadioParameters(genres: Array(selectedGenres).sorted(), artistIds: selectedArtists.map(\.id), albumIds: selectedAlbums.map(\.id)) }

    func loadGenres() async {
        guard !isLoadingGenres, let token = session.token else { return }
        isLoadingGenres = true
        defer { isLoadingGenres = false }
        do { let response: GenreResponse = try await APIClient.shared.request("/radio/genres", token: token); genres = response.genres }
        catch { errorMessage = error.localizedDescription }
    }
    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = searchType
        guard let token = session.token, !query.isEmpty else { searchResults = []; return }
        errorMessage = nil
        do {
            let response: PickerResults = try await APIClient.shared.request(searchPath(query: query, type: type), token: token)
            guard !Task.isCancelled, searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query, searchType == type else { return }
            searchResults = response.items
        } catch {
            guard !Task.isCancelled, (error as? URLError)?.code != .cancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
    private func searchPath(query: String, type: String) -> String {
        var c = URLComponents(); c.path = "/radio/search"; c.queryItems = [.init(name: "q", value: query), .init(name: "type", value: type)]
        return c.string ?? "/radio/search"
    }
    func toggleGenre(_ genre: String) { if selectedGenres.contains(genre) { selectedGenres.remove(genre) } else if canAddSelection { selectedGenres.insert(genre) } }
    func isSelected(_ item: PickerItem, type: String) -> Bool {
        type == "artist"
            ? selectedArtists.contains(where: { $0.id == item.id })
            : selectedAlbums.contains(where: { $0.id == item.id })
    }
    @discardableResult
    func add(_ item: PickerItem, type: String) -> Bool {
        guard !isSelected(item, type: type), canAddSelection else { return false }
        if type == "artist" { selectedArtists.append(item) }
        else if type == "album" { selectedAlbums.append(item) }
        else { return false }
        return true
    }
    func remove(_ item: PickerItem) { selectedArtists.removeAll { $0.id == item.id }; selectedAlbums.removeAll { $0.id == item.id } }

    func startRadio(using parameters: RadioParameters) async {
        guard let token = session.token else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let radio: RadioResponse = try await APIClient.shared.request("/radio/start", method: "POST", body: parameters, token: token)
            radioSessionID = radio.radioSessionId
            startBackendKeepAlive()
            liveActivity.start(sessionID: radio.radioSessionId)
            let track = try await nextTrack()
            reservations[track.trackUri] = track.playHistoryId
            remote.authorizeAndPlay(track.trackUri)
        } catch { errorMessage = error.localizedDescription; liveActivity.end(); stopBackendKeepAlive(); radioSessionID = nil }
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
        let endingSessionID = radioSessionID
        liveActivity.end()
        stopBackendKeepAlive()
        radioSessionID = nil
        clearFilters()
        await remote.stopPlayback()
        if let token = session.token, let id = endingSessionID {
            try? await APIClient.shared.noContent("/radio/\(id)/end", method: "POST", token: token)
        }
    }

    func restartRadio() async {
        guard !isLoading else { return }
        let currentParameters = parameters
        let endingSessionID = radioSessionID
        isLoading = true
        defer { isLoading = false }
        liveActivity.end()
        stopBackendKeepAlive()
        await remote.stopPlayback()
        if let token = session.token, let id = endingSessionID {
            try? await APIClient.shared.noContent("/radio/\(id)/end", method: "POST", token: token)
        }
        await startRadio(using: currentParameters)
    }

    private func clearFilters() {
        selectedGenres.removeAll()
        selectedArtists.removeAll()
        selectedAlbums.removeAll()
        searchText = ""
        searchResults = []
        errorMessage = nil
    }

    func keepBackendWarmIfRadioIsActive() async {
        guard radioSessionID != nil else { return }
        try? await APIClient.shared.checkHealth()
    }

    private func startBackendKeepAlive() {
        stopBackendKeepAlive()
        backendKeepAliveTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000) }
                catch { return }
                guard let self, self.radioSessionID != nil, !Task.isCancelled else { return }
                try? await APIClient.shared.checkHealth()
            }
        }
    }

    private func stopBackendKeepAlive() {
        backendKeepAliveTask?.cancel()
        backendKeepAliveTask = nil
    }
}
