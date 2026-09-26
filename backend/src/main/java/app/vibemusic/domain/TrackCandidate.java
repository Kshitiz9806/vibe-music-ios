package app.vibemusic.domain;
import java.util.Set;
public record TrackCandidate(String id,String uri,Set<String> artistIds,String albumId,Set<String> genres) {}
