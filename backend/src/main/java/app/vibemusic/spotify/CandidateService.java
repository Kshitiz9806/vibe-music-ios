package app.vibemusic.spotify;

import app.vibemusic.domain.TrackCandidate;
import app.vibemusic.model.RadioSession;
import app.vibemusic.model.UserAccount;
import org.springframework.stereotype.Service;
import tools.jackson.databind.JsonNode;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

@Service
public class CandidateService {
    private static final int SEARCH_LIMIT = 10;
    private final SpotifyClient spotify;

    public CandidateService(SpotifyClient spotify) {
        this.spotify = spotify;
    }

    public java.util.List<TrackCandidate> candidates(RadioSession session) {
        Map<String, TrackCandidate> result = new LinkedHashMap<>();
        UserAccount user = session.getUser();

        for (String artistId : session.getArtistIds()) {
            JsonNode artist = spotify.get("/artists/" + enc(artistId), user);
            String artistName = artist.path("name").asText();
            if (artistName.isBlank()) continue;

            Set<String> genres = new HashSet<>();
            artist.path("genres").forEach(genre -> genres.add(genre.asText()));
            String query = "artist:\"" + artistName.replace('"', ' ').trim() + "\"";
            JsonNode tracks = spotify.get("/search", Map.of(
                    "q", query,
                    "type", "track",
                    "limit", SEARCH_LIMIT
            ), user).path("tracks").path("items");
            add(result, tracks, null, genres);
        }

        for (String albumId : session.getAlbumIds()) {
            JsonNode tracks = spotify.get("/albums/" + enc(albumId) + "/tracks", Map.of("limit", 50), user)
                    .path("items");
            add(result, tracks, albumId, Set.of());
        }

        for (String genre : session.getGenres()) {
            String query = "genre:" + genre.replace(":", "").replace("\"", "").trim();
            JsonNode tracks = spotify.get("/search", Map.of(
                    "q", query,
                    "type", "track",
                    "limit", SEARCH_LIMIT
            ), user).path("tracks").path("items");
            add(result, tracks, null, Set.of(genre));
        }

        if (session.getGenres().isEmpty() && session.getArtistIds().isEmpty() && session.getAlbumIds().isEmpty()) {
            add(result, spotify.get("/me/top/tracks", Map.of("limit", 50), user).path("items"), null, Set.of());
            add(result, spotify.get("/me/tracks", Map.of("limit", 50), user).path("items"), null, Set.of());
        }

        return java.util.List.copyOf(result.values());
    }

    private void add(Map<String, TrackCandidate> result, JsonNode tracks, String sourceAlbum, Set<String> sourceGenres) {
        if (!tracks.isArray()) return;
        for (JsonNode item : tracks) {
            JsonNode track = item.has("track") ? item.path("track") : item;
            String id = track.path("id").asText();
            String uri = track.path("uri").asText();
            if (id.isBlank() || uri.isBlank()) continue;

            Set<String> artists = new HashSet<>();
            for (JsonNode artist : track.path("artists")) {
                String artistId = artist.path("id").asText();
                if (!artistId.isBlank()) artists.add(artistId);
            }

            String album = track.path("album").path("id").asText();
            if (album.isBlank()) album = track.path("album_id").asText();
            if (album.isBlank()) album = sourceAlbum == null ? "" : sourceAlbum;

            TrackCandidate candidate = new TrackCandidate(id, uri, artists, album, Set.copyOf(sourceGenres));
            result.merge(id, candidate, (existing, incoming) -> {
                Set<String> genres = new HashSet<>(existing.genres());
                genres.addAll(incoming.genres());
                return new TrackCandidate(existing.id(), existing.uri(), existing.artistIds(), existing.albumId(), genres);
            });
        }
    }

    private String enc(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }
}
