package app.vibemusic.api;

import app.vibemusic.domain.RecommendationEngine;
import app.vibemusic.domain.TrackCandidate;
import app.vibemusic.model.*;
import app.vibemusic.repo.*;
import app.vibemusic.security.SessionIdentity;
import app.vibemusic.spotify.CandidateService;
import app.vibemusic.spotify.SpotifyClient;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.time.Duration;
import java.time.Instant;
import java.util.*;

@RestController @RequestMapping("/radio")
public class RadioController {
 private final IdentityResolver identities;private final RadioSessionRepository radios;private final PlayHistoryRepository history;private final CandidateService candidates;private final RecommendationEngine engine;private final SpotifyClient spotify;private final Duration noRepeat;
 public RadioController(IdentityResolver identities,RadioSessionRepository radios,PlayHistoryRepository history,CandidateService candidates,RecommendationEngine engine,SpotifyClient spotify,@Value("${vibemusic.no-repeat-window:P30D}") Duration noRepeat){this.identities=identities;this.radios=radios;this.history=history;this.candidates=candidates;this.engine=engine;this.spotify=spotify;this.noRepeat=noRepeat;}
 public record Params(List<String> genres,List<String> artistIds,List<String> albumIds){
  public Params{genres=clean(genres);artistIds=clean(artistIds);albumIds=clean(albumIds);}private static List<String> clean(List<String> in){return in==null?List.of():in.stream().filter(Objects::nonNull).map(String::trim).filter(s->!s.isEmpty()).distinct().toList();}int total(){return genres.size()+artistIds.size()+albumIds.size();}
 }
 private RadioSession create(UserAccount user,Params p){if(p.total()>5)throw new ApiException("TOO_MANY_PARAMS","genres + artistIds + albumIds must total 5 or fewer",400);RadioSession session=new RadioSession(user,p.genres(),p.artistIds(),p.albumIds());return radios.save(session);}
 @PostMapping("/start") @Transactional public ResponseEntity<?> start(@Valid @RequestBody Params p,HttpServletRequest request){SessionIdentity i=identities.required(request);RadioSession r=create(i.user(),p);return ResponseEntity.status(201).body(Map.of("radioSessionId",r.getId(),"startedAt",r.getStartedAt()));}
 @PostMapping("/{id}/restart") @Transactional public ResponseEntity<?> restart(@PathVariable String id,@Valid @RequestBody Params p,HttpServletRequest request){SessionIdentity i=identities.required(request);RadioSession old=owned(id,i);old.end();RadioSession r=create(i.user(),p);return ResponseEntity.status(201).body(Map.of("radioSessionId",r.getId(),"startedAt",r.getStartedAt()));}
 @PostMapping("/{id}/end") @Transactional public ResponseEntity<Void> end(@PathVariable String id,HttpServletRequest request){RadioSession r=owned(id,identities.required(request));r.end();return ResponseEntity.noContent().build();}
 @GetMapping("/{id}/next-track") @Transactional public ResponseEntity<?> next(@PathVariable String id,HttpServletRequest request){RadioSession r=owned(id,identities.required(request));if(!r.isActive())throw new ApiException("SESSION_ENDED","Radio session has ended",409);Set<String> played=history.findRecentlyPlayed(r.getUser().getId(),Instant.now().minus(noRepeat));List<TrackCandidate> pool=candidates.candidates(r);Optional<TrackCandidate> choice=engine.select(pool,r,played);if(choice.isEmpty())return ResponseEntity.noContent().build();PlayHistory h=history.save(new PlayHistory(r.getUser(),r,choice.get().id()));r.touch();return ResponseEntity.ok(Map.of("trackUri",choice.get().uri(),"playHistoryId",h.getPlayHistoryId()));}
 public record MarkPlayed(@jakarta.validation.constraints.NotBlank String playHistoryId,Instant playedAt){}
 @PostMapping("/{id}/mark-played") @Transactional public ResponseEntity<Void> markPlayed(@PathVariable String id,@Valid @RequestBody MarkPlayed body,HttpServletRequest request){RadioSession r=owned(id,identities.required(request));PlayHistory h=history.findByPlayHistoryId(body.playHistoryId()).orElseThrow(()->new ApiException("NOT_FOUND","Play reservation not found",404));if(!h.belongsTo(r.getId()))throw new ApiException("NOT_FOUND","Play reservation not found",404);h.markPlayed(body.playedAt()==null?Instant.now():body.playedAt());r.touch();return ResponseEntity.noContent().build();}
 @GetMapping("/genres") public ResponseEntity<?> genres(HttpServletRequest request){UserAccount user=identities.user(request);LinkedHashSet<String> genres=new LinkedHashSet<>();try{var data=spotify.get("/me/top/artists",Map.of("limit",50),user);for(var artist:data.path("items"))artist.path("genres").forEach(g->genres.add(g.asText()));}catch(Exception ignored){}
  return ResponseEntity.ok(Map.of("genres",genres.stream().sorted(String.CASE_INSENSITIVE_ORDER).toList()));}
 @GetMapping("/search") public ResponseEntity<?> search(@RequestParam String q,@RequestParam String type,HttpServletRequest request){if(!Set.of("artist","album").contains(type))throw new ApiException("INVALID_SEARCH_TYPE","type must be artist or album",400);if(q.isBlank())return ResponseEntity.ok(Map.of("items",List.of()));var results=spotify.get("/search",Map.of("q",q,"type",type,"limit",20),identities.user(request)).path(type+"s").path("items");List<Map<String,String>> items=new ArrayList<>();if(results.isArray())for(var item:results){String id=item.path("id").asText(),name=item.path("name").asText();if(id.isBlank()||name.isBlank())continue;String subtitle=type.equals("album")?item.path("artists").path(0).path("name").asText(""):item.path("genres").isArray()?item.path("genres").toString():"";items.add(Map.of("id",id,"name",name,"subtitle",subtitle));}return ResponseEntity.ok(Map.of("items",items));}
 private RadioSession owned(String id,SessionIdentity identity){RadioSession r=radios.findByIdAndUser_Id(id,identity.user().getId()).orElseThrow(()->new ApiException("NOT_FOUND","Radio session not found",404));r.touch();return r;}
}
