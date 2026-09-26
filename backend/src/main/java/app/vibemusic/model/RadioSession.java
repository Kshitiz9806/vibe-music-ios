package app.vibemusic.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity @Table(name="radio_sessions")
public class RadioSession {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private String id;
    @ManyToOne(optional=false,fetch=FetchType.LAZY) private UserAccount user;
    @ElementCollection @CollectionTable(name="radio_genres",joinColumns=@JoinColumn(name="session_id")) @Column(name="genre") private List<String> genres=new ArrayList<>();
    @ElementCollection @CollectionTable(name="radio_artists",joinColumns=@JoinColumn(name="session_id")) @Column(name="artist_id") private List<String> artistIds=new ArrayList<>();
    @ElementCollection @CollectionTable(name="radio_albums",joinColumns=@JoinColumn(name="session_id")) @Column(name="album_id") private List<String> albumIds=new ArrayList<>();
    @Column(nullable=false) private Instant startedAt=Instant.now();
    private Instant lastActivityAt=Instant.now(); private Instant endedAt;
    protected RadioSession() {}
    public RadioSession(UserAccount user,List<String> genres,List<String> artistIds,List<String> albumIds){this.user=user;this.genres.addAll(genres);this.artistIds.addAll(artistIds);this.albumIds.addAll(albumIds);}
    public String getId(){return id;} public UserAccount getUser(){return user;} public List<String> getGenres(){return List.copyOf(genres);} public List<String> getArtistIds(){return List.copyOf(artistIds);} public List<String> getAlbumIds(){return List.copyOf(albumIds);}
    public Instant getStartedAt(){return startedAt;} public Instant getLastActivityAt(){return lastActivityAt;} public Instant getEndedAt(){return endedAt;} public boolean isActive(){return endedAt==null;}
    public void touch(){lastActivityAt=Instant.now();} public void end(){endedAt=Instant.now();}
}
