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
    let start: (RadioParameters) -> Void
    let signOut: () -> Void
    @State private var addedMessage: String?
    @State private var addedMessageToken = UUID()
    @FocusState private var isSearchFocused: Bool
    private var genreRows: [[String]] {
        (0..<3).map { row in
            model.genres.enumerated().compactMap { $0.offset % 3 == row ? $0.element : nil }
        }
    }
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
                    .font(.subheadline.weight(.bold))
                    .tracking(2)
                Spacer()
                Button("Sign out", action: signOut)
                    .font(.footnote.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Your filters").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(model.selectionCount) / 5")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(model.selectionCount == 5 ? .orange : .secondary)
                }
                if selectedItems.isEmpty {
                    Text("Choose up to five genres, artists, or albums.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    FlowChips(items: selectedItems, remove: removeSelection)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if let addedMessage {
                    Label(addedMessage, systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.medium)).foregroundStyle(.green)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Set your direction").font(.title2.bold())
                        Text("Pick up to five filters. The radio handles the rest.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("Genres").font(.subheadline.weight(.semibold))
                        if model.genres.isEmpty {
                            if model.isLoadingGenres {
                                ProgressView("Loading genres…").font(.footnote).tint(.green)
                            } else {
                                Button { Task { await model.loadGenres() } } label: {
                                    Label("Genres unavailable. Tap to retry.", systemImage: "arrow.clockwise")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(genreRows.enumerated()), id: \.offset) { row in
                                        HStack(spacing: 8) {
                                            ForEach(row.element, id: \.self) { genre in
                                                let selected = model.selectedGenres.contains(genre)
                                                Button {
                                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                                        model.toggleGenre(genre)
                                                    }
                                                    if !selected && model.selectedGenres.contains(genre) { showAdded("\(genre.capitalized) added") }
                                                } label: {
                                                    HStack(spacing: 5) {
                                                        if selected { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                                                        Text(genre.capitalized).font(.footnote).lineLimit(1)
                                                    }
                                                    .fixedSize()
                                                    .padding(.horizontal, 11).padding(.vertical, 7)
                                                    .foregroundStyle(selected ? Color.black : Color.primary)
                                                    .background(selected ? Color.green : Color(uiColor: .secondarySystemBackground), in: Capsule())
                                                }
                                                .buttonStyle(.plain)
                                                .disabled(!selected && !model.canAddSelection)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(height: 118)
                        }
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text("Find music").font(.subheadline.weight(.semibold))
                            Spacer()
                            Picker("Search by", selection: $model.searchType) {
                                Text("Artist").tag("artist")
                                Text("Album").tag("album")
                            }
                            .pickerStyle(.menu)
                            .tint(.green)
                        }
                        HStack(spacing: 9) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField(model.searchType == "artist" ? "Search artists" : "Search albums", text: $model.searchText)
                                .font(.subheadline)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .focused($isSearchFocused)
                                .submitLabel(.search)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                        ForEach(model.searchResults) { item in
                            let type = model.searchType
                            let selected = model.isSelected(item, type: type)
                            Button {
                                if model.add(item, type: type) { showAdded("\(item.name) added") }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: type == "artist" ? "person.crop.circle" : "square.stack")
                                        .font(.body).foregroundStyle(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).font(.subheadline).foregroundStyle(.primary)
                                        if !item.subtitle.isEmpty {
                                            Text(item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle.fill")
                                        .font(.title3).foregroundStyle(selected ? Color.green : Color.secondary)
                                }
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(selected || !model.canAddSelection)
                        }
                    }

                    if let error = model.errorMessage { Text(error).font(.footnote).foregroundStyle(.red) }
                    Text("With no selections, VibeMusic uses your top tracks and saved music.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)

            if !isSearchFocused {
                Button { start(model.parameters) } label: {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isSearchFocused = false }
            }
        }
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

    private func showAdded(_ message: String) {
        let token = UUID()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            addedMessage = message
            addedMessageToken = token
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard addedMessageToken == token else { return }
            withAnimation(.easeOut(duration: 0.2)) { addedMessage = nil }
        }
    }
}

struct PlayerView: View {
    @ObservedObject var model: RadioViewModel
    @ObservedObject var remote: SpotifyRemote
    let restart: () -> Void
    let end: () -> Void
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
                }
                .accessibilityLabel(remote.isPlaying ? "Pause" : "Play")
                .disabled(model.isLoading)
                Spacer(minLength: 8)
                if let error = remote.errorMessage ?? model.errorMessage { Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center) }
                HStack(spacing: 10) {
                    Button(action: restart) {
                        Label(model.isLoading ? "Restarting…" : "Restart Radio", systemImage: "arrow.counterclockwise")
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isLoading)

                    Button(action: end) {
                        Label("End Radio", systemImage: "stop.fill")
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(.white)
                            .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isLoading)
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
            HStack {
                ForEach(items) { item in
                    Button { remove(item.id) } label: {
                        HStack(spacing: 8) {
                            Text(item.title).font(.caption.weight(.medium)).lineLimit(1)
                            Image(systemName: "xmark.circle.fill").font(.system(size: 16, weight: .semibold))
                        }
                        .padding(.horizontal, 12).frame(minHeight: 42)
                        .foregroundStyle(.primary)
                        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(item.title)")
                }
            }
        }
    }
}
