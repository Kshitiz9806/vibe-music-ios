package app.vibemusic.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="play_history")
public class PlayHistory {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private String id;
    @ManyToOne(optional=false,fetch=FetchType.LAZY) private UserAccount user;
    @ManyToOne(optional=false,fetch=FetchType.LAZY) private RadioSession radioSession;
    @Column(nullable=false) private String trackId;
    @Column(nullable=false) private String playHistoryId;
    @Column(nullable=false) private Instant reservedAt=Instant.now();
    private Instant playedAt;
    protected PlayHistory() {}
    public PlayHistory(UserAccount user,RadioSession session,String trackId){this.user=user;this.radioSession=session;this.trackId=trackId;this.playHistoryId="ph_"+java.util.UUID.randomUUID().toString().replace("-","");}
    public String getId(){return id;} public String getTrackId(){return trackId;} public String getPlayHistoryId(){return playHistoryId;} public Instant getPlayedAt(){return playedAt;}
    public boolean belongsTo(String sessionId){return radioSession.getId().equals(sessionId);} public void markPlayed(Instant at){if(playedAt==null)playedAt=at;}
}
