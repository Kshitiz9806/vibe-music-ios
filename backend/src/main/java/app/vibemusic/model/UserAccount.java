package app.vibemusic.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="users", uniqueConstraints=@UniqueConstraint(columnNames="spotify_user_id"))
public class UserAccount {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private String id;
    @Column(name="spotify_user_id", nullable=false) private String spotifyUserId;
    @Column(nullable=false) private String displayName;
    private boolean premium;
    @Column(length=4096) private String accessToken;
    @Column(length=4096) private String encryptedRefreshToken;
    private Instant tokenExpiresAt;
    private Instant createdAt=Instant.now();
    protected UserAccount() {}
    public UserAccount(String spotifyUserId, String displayName, boolean premium, String accessToken, String refreshToken, Instant expiresAt) {
        this.spotifyUserId=spotifyUserId; this.displayName=displayName; this.premium=premium; this.accessToken=accessToken; this.encryptedRefreshToken=refreshToken; this.tokenExpiresAt=expiresAt;
    }
    public String getId(){return id;} public String getSpotifyUserId(){return spotifyUserId;} public String getDisplayName(){return displayName;} public boolean isPremium(){return premium;}
    public String getAccessToken(){return accessToken;} public String getEncryptedRefreshToken(){return encryptedRefreshToken;} public Instant getTokenExpiresAt(){return tokenExpiresAt;}
    public void updateTokens(String access,String refresh,Instant expires){accessToken=access;if(refresh!=null)encryptedRefreshToken=refresh;tokenExpiresAt=expires;}
    public void updateProfile(String name,boolean isPremium){displayName=name;premium=isPremium;}
}
