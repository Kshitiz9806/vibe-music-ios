package app.vibemusic.spotify;

import app.vibemusic.domain.TrackCandidate;
import app.vibemusic.model.RadioSession;
import app.vibemusic.model.UserAccount;
import tools.jackson.databind.JsonNode;
import org.springframework.stereotype.Service;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class CandidateService {
    private final SpotifyClient spotify;
    private final Map<String,Set<String>> genreCache=new ConcurrentHashMap<>();
    public CandidateService(SpotifyClient spotify){this.spotify=spotify;}
    public List<TrackCandidate> candidates(RadioSession session){LinkedHashMap<String,TrackCandidate> result=new LinkedHashMap<>();UserAccount user=session.getUser();
        for(String artist:session.getArtistIds())add(result,spotify.get("/artists/"+enc(artist)+"/top-tracks",Map.of("market","from_token"),user).path("tracks"),user,null);
        for(String album:session.getAlbumIds())add(result,spotify.get("/albums/"+enc(album)+"/tracks",Map.of("limit",50),user).path("items"),user,album);
        for(String genre:session.getGenres()){
            String query="genre:"+genre.replace(":","").replace("\"","").trim();
            add(result,spotify.get("/search",Map.of("q",query,"type","track","limit",50),user).path("tracks").path("items"),user,null);
        }
        if(session.getGenres().isEmpty()&&session.getArtistIds().isEmpty()&&session.getAlbumIds().isEmpty()){
            add(result,spotify.get("/me/top/tracks",Map.of("limit",50),user).path("items"),user,null);
            add(result,spotify.get("/me/tracks",Map.of("limit",50),user).path("items"),user,null);
        }
        Set<String> missing=new LinkedHashSet<>();result.values().forEach(t->t.artistIds().forEach(a->{if(!genreCache.containsKey(a))missing.add(a);}));
        List<String> ids=new ArrayList<>(missing);for(int start=0;start<ids.size();start+=50){List<String> batch=ids.subList(start,Math.min(start+50,ids.size()));try{JsonNode artists=spotify.get("/artists",Map.of("ids",String.join(",",batch)),user).path("artists");for(JsonNode artist:artists){String artistId=artist.path("id").asText();Set<String> tags=new HashSet<>();artist.path("genres").forEach(g->tags.add(g.asText()));genreCache.put(artistId,Set.copyOf(tags));}}catch(Exception ignored){batch.forEach(a->genreCache.putIfAbsent(a,Set.of()));}}
        return result.values().stream().map(t->{Set<String> tags=new HashSet<>();t.artistIds().forEach(a->tags.addAll(genreCache.getOrDefault(a,Set.of())));return new TrackCandidate(t.id(),t.uri(),t.artistIds(),t.albumId(),tags);}).toList();
    }
    private void add(Map<String,TrackCandidate> result,JsonNode tracks,UserAccount user,String sourceAlbum){if(!tracks.isArray())return;for(JsonNode item:tracks){JsonNode track=item.has("track")?item.path("track"):item;String id=track.path("id").asText();String uri=track.path("uri").asText();if(id.isBlank()||uri.isBlank())continue;Set<String> artists=new HashSet<>();for(JsonNode a:track.path("artists")){String aid=a.path("id").asText();if(!aid.isBlank())artists.add(aid);}
            String album=track.path("album").path("id").asText();if(album.isBlank())album=track.path("album_id").asText();if(album.isBlank())album=sourceAlbum==null?"":sourceAlbum;result.putIfAbsent(id,new TrackCandidate(id,uri,artists,album,Set.of()));}}
    private String enc(String value){return URLEncoder.encode(value,StandardCharsets.UTF_8);}
}
