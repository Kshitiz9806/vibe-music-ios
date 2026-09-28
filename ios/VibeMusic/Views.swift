import SwiftUI

struct SignInView: View {
    let login: SpotifyLogin
    let didSignIn: (SessionResponse) -> Void
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.green)
                Text("VibeMusic").font(.title2.bold())
                Text("Choose the shape of a session. Then let the radio take it from there.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center) }
            Spacer(minLength: 24)
            Button {
                busy = true
                Task { defer { busy = false }; do { didSignIn(try await login.signIn()) } catch { self.error = error.localizedDescription } }
            } label: {
                HStack { if busy { ProgressView().tint(.black) }; Text(busy ? "Connecting…" : "Continue with Spotify") }
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 14).foregroundStyle(.black).background(.green, in: Capsule())
            }.disabled(busy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }
}

struct LandingView: View {
    @ObservedObject var model: RadioViewModel
    let start: () -> Void
    let signOut: () -> Void
    private let columns = [GridItem(.adaptive(minimum: 112), spacing: 8)]
    private var selectedItems: [SelectedChip] {
        let genres = model.selectedGenres.sorted().map { SelectedChip(id: $0, title: $0) }
        let artists = model.selectedArtists.map { SelectedChip(id: $0.id, title: $0.name) }
        let albums = model.selectedAlbums.map { SelectedChip(id: $0.id, title: $0.name) }
        return genres + artists + albums
    }

    private func removeSelection(_ id: String) {
        if model.selectedGenres.contains(id) {
            model.toggleGenre(id)
        } else if let item = model.selectedArtists.first(where: { $0.id == id })
                    ?? model.selectedAlbums.first(where: { $0.id == id }) {
            model.remove(item)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("VIBEMUSIC")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                Spacer()
                Button("Sign out", action: signOut)
                    .font(.footnote.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Set your direction").font(.title2.bold())
                            Text("Pick up to five ingredients. The radio handles the rest.").font(.footnote).foregroundStyle(.secondary)
                        }
                        HStack { Text("Selections").font(.subheadline.weight(.semibold)); Spacer(); Text("\(model.selectionCount) / 5").font(.footnote.monospacedDigit()).foregroundStyle(model.selectionCount == 5 ? .orange : .secondary) }
                        if !model.selectedGenres.isEmpty || !model.selectedArtists.isEmpty || !model.selectedAlbums.isEmpty {
                            FlowChips(items: selectedItems, remove: removeSelection)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Genres").font(.subheadline.weight(.semibold))
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                                ForEach(model.genres, id: \.self) { genre in
                                    let selected = model.selectedGenres.contains(genre)
                                    Button { model.toggleGenre(genre) } label: {
                                        Text(genre.capitalized).font(.footnote).lineLimit(1).frame(maxWidth: .infinity).padding(.vertical, 8).padding(.horizontal, 10)
                                            .foregroundColor(selected ? .black : Color.primary).background(selected ? Color.green : Color(uiColor: .secondarySystemBackground), in: Capsule())
                                    }.disabled(!selected && !model.canAddSelection)
                                }
                            }
                            if model.genres.isEmpty {
                                if model.isLoadingGenres {
                                    ProgressView("Loading genres…").font(.footnote).tint(.green)
                                } else {
                                    Button {
                                        Task { await model.loadGenres() }
                                    } label: {
                                        Label("Genres unavailable. Tap to retry.", systemImage: "arrow.clockwise")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Artists and albums").font(.subheadline.weight(.semibold))
                            HStack(spacing: 4) {
                                ForEach(["artist", "album"], id: \.self) { type in
                                    let title = type == "artist" ? "Artists" : "Albums"
                                    Button { model.searchType = type } label: {
                                        Text(title)
                                            .font(.footnote.weight(.medium))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                model.searchType == type ? Color(uiColor: .secondarySystemBackground) : .clear,
                                                in: Capsule()
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(model.searchType == type ? .isSelected : [])
                                }
                            }
                            .padding(4)
                            .background(Color(uiColor: .tertiarySystemBackground), in: Capsule())
                            TextField(model.searchType == "artist" ? "Search artists" : "Search albums", text: $model.searchText)
                                .font(.subheadline)
                                .textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                            ForEach(model.searchResults) { item in
                                Button { model.add(item) } label: {
                                    HStack(spacing: 10) { Image(systemName: model.searchType == "artist" ? "person.crop.circle" : "square.stack").font(.footnote).foregroundStyle(.green); VStack(alignment: .leading) { Text(item.name).font(.subheadline).foregroundStyle(.primary); if !item.subtitle.isEmpty { Text(item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1) } }; Spacer(); Image(systemName: "plus.circle.fill").font(.system(size: 22, weight: .medium)).foregroundStyle(.green).frame(width: 44, height: 44).contentShape(Rectangle()) }
                                        .padding(.vertical, 4)
                                }.disabled(!model.canAddSelection)
                            }
                        }
                        if let error = model.errorMessage { Text(error).font(.footnote).foregroundStyle(.red) }
                        Text("With no selections, VibeMusic uses your top tracks and saved music.").font(.caption).foregroundStyle(.secondary)
                    }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)

            Button(action: start) {
                HStack {
                    if model.isLoading { ProgressView().tint(.black) }
                    Text(model.isLoading ? "Starting…" : "Start Vibe Radio")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 13)
                .padding(.horizontal, 16)
                .foregroundStyle(.black)
                .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(model.isLoading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color(uiColor: .systemBackground).opacity(0.97))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .task { await model.loadGenres() }
        .task(id: model.searchText + model.searchType) {
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await model.search()
        }
    }
}

struct PlayerView: View {
    @ObservedObject var model: RadioViewModel
    @ObservedObject var remote: SpotifyRemote
    let restart: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        GeometryReader { geometry in
            let artworkSize = min(geometry.size.width - 32, geometry.size.height * 0.40)
            VStack(spacing: 12) {
                HStack { Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(.green); Text("VIBE RADIO").font(.caption.bold()).tracking(2); Spacer(); Circle().fill(remote.isConnected ? .green : .orange).frame(width: 8, height: 8) }
                Spacer(minLength: 8)
                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(LinearGradient(colors: [Color.green.opacity(0.8), Color.teal.opacity(0.45), Color.blue.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "waveform").font(.system(size: 48, weight: .light)).foregroundStyle(.white.opacity(0.92))
                }.frame(width: artworkSize, height: artworkSize)
                Spacer(minLength: 8)
                Text("Your vibe is on").font(.title3.bold())
                Text(remote.isPlaying ? "Finding the flow" : "Paused when you are").font(.footnote).foregroundStyle(.secondary)
                VStack(spacing: 6) {
                    ProgressView(value: remote.duration > 0 ? min(remote.position / remote.duration, 1) : 0).tint(.green)
                    HStack { Text(time(remote.position)); Spacer(); Text(time(remote.duration)) }.font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }.padding(.top, 8)
                Button { remote.togglePlayback() } label: {
                    Image(systemName: remote.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(.black).frame(width: 56, height: 56).background(.green, in: Circle())
                }.accessibilityLabel(remote.isPlaying ? "Pause" : "Play")
                Spacer(minLength: 8)
                if let error = remote.errorMessage ?? model.errorMessage { Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center) }
                Button(action: restart) {
                    Label("Restart Radio", systemImage: "arrow.counterclockwise").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 13).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 13))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            remote.resumeConnection()
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: scenePhase) { phase in
            UIApplication.shared.isIdleTimerDisabled = phase == .active
            if phase == .active {
                remote.resumeConnection()
                Task { await model.keepBackendWarmIfRadioIsActive() }
            }
            else { remote.suspendConnection() }
        }
    }
    private func time(_ value: Double) -> String { guard value.isFinite else { return "0:00" }; return String(format: "%d:%02d", Int(value) / 60, Int(value) % 60) }
}

private struct SelectedChip: Identifiable { let id: String; let title: String }
private struct FlowChips: View {
    let items: [SelectedChip]
    let remove: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack { ForEach(items) { item in Button { remove(item.id) } label: { Label(item.title, systemImage: "xmark.circle.fill").font(.caption).padding(.horizontal, 11).padding(.vertical, 8).foregroundStyle(.primary).background(Color(uiColor: .secondarySystemBackground), in: Capsule()) } } }
        }
    }
}
