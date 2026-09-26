package app.vibemusic.domain;

import app.vibemusic.model.RadioSession;
import org.springframework.stereotype.Component;
import org.springframework.beans.factory.annotation.Value;
import java.util.*;
import java.util.concurrent.ThreadLocalRandom;

@Component
public class RecommendationEngine {
    private final double genreWeight,artistWeight,albumWeight;
    public RecommendationEngine(@Value("${vibemusic.scoring.genre-weight:1.0}") double genreWeight,@Value("${vibemusic.scoring.artist-weight:1.0}") double artistWeight,@Value("${vibemusic.scoring.album-weight:1.0}") double albumWeight){this.genreWeight=Math.max(0,genreWeight);this.artistWeight=Math.max(0,artistWeight);this.albumWeight=Math.max(0,albumWeight);}
    public Optional<TrackCandidate> select(Collection<TrackCandidate> candidates,RadioSession session,Set<String> recentlyPlayed){
        List<Scored> scored=candidates.stream().filter(c->!recentlyPlayed.contains(c.id())).collect(java.util.stream.Collectors.toMap(TrackCandidate::id,c->c,(a,b)->a,LinkedHashMap::new)).values().stream().map(c->new Scored(c,score(c,session))).sorted(Comparator.comparingDouble(Scored::score).reversed()).toList();
        if(scored.isEmpty())return Optional.empty();int count=Math.min(scored.size(),Math.max(10,Math.min(30,(int)Math.ceil(scored.size()*0.4))));List<Scored> window=scored.subList(0,count);double sum=window.stream().mapToDouble(s->Math.max(0,s.score())).sum();double r=ThreadLocalRandom.current().nextDouble()*(sum>0?sum:window.size());
        for(Scored candidate:window){r-=sum>0?Math.max(0,candidate.score()):1;if(r<=0)return Optional.of(candidate.track());}return Optional.of(window.get(window.size()-1).track());
    }
    public double score(TrackCandidate t,RadioSession s){double total=0,weights=0;for(String genre:s.getGenres()){total+=genreScore(genre,t.genres())*genreWeight;weights+=genreWeight;}for(String artist:s.getArtistIds()){total+=(t.artistIds().contains(artist)?1:0)*artistWeight;weights+=artistWeight;}for(String album:s.getAlbumIds()){total+=(Objects.equals(album,t.albumId())?1:0)*albumWeight;weights+=albumWeight;}return weights==0?0:total/weights;}
    private double genreScore(String selected,Set<String> actual){String wanted=norm(selected);for(String g:actual){String tag=norm(g);if(tag.equals(wanted))return 1;if(tag.contains(wanted)||wanted.contains(tag))return 0.5;Set<String> a=new HashSet<>(Arrays.asList(wanted.split("[^a-z0-9]+")));a.remove("");Set<String>b=new HashSet<>(Arrays.asList(tag.split("[^a-z0-9]+")));b.remove("");if(!a.isEmpty()&&!b.isEmpty()&&!Collections.disjoint(a,b))return 0.25;}return 0;}
    private String norm(String s){return s==null?"":s.toLowerCase(Locale.ROOT).replace('_',' ').trim();}
    private record Scored(TrackCandidate track,double score){}
}
