package app.vibemusic.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="api_sessions")
public class ApiSession {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private String id;
    @ManyToOne(optional=false, fetch=FetchType.LAZY) private UserAccount user;
    @Column(nullable=false, unique=true) private String tokenHash;
    @Column(nullable=false) private Instant createdAt=Instant.now();
    @Column(nullable=false) private Instant expiresAt;
    protected ApiSession() {}
    public ApiSession(UserAccount user,String hash,Instant expiresAt){this.user=user;this.tokenHash=hash;this.expiresAt=expiresAt;}
    public String getId(){return id;} public UserAccount getUser(){return user;} public Instant getExpiresAt(){return expiresAt;} public boolean isValid(){return expiresAt.isAfter(Instant.now());}
}
