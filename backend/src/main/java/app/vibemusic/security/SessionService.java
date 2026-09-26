package app.vibemusic.security;

import app.vibemusic.model.ApiSession;
import app.vibemusic.model.UserAccount;
import app.vibemusic.repo.ApiSessionRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;

@Service
public class SessionService {
    private final ApiSessionRepository sessions; private final Duration lifetime; private final SecureRandom random=new SecureRandom();
    public SessionService(ApiSessionRepository sessions,@Value("${vibemusic.session-lifetime:P7D}") Duration lifetime){this.sessions=sessions;this.lifetime=lifetime;}
    public Issued issue(UserAccount user){byte[] raw=new byte[32];random.nextBytes(raw);String token=Base64.getUrlEncoder().withoutPadding().encodeToString(raw);sessions.save(new ApiSession(user,digest(token),Instant.now().plus(lifetime)));return new Issued(token,Instant.now().plus(lifetime));}
    public ApiSession find(String token){return sessions.findByTokenHashAndExpiresAtAfter(digest(token),Instant.now()).orElse(null);}
    public void revoke(String token){ApiSession session=find(token);if(session!=null)sessions.delete(session);}
    private String digest(String token){try{return Base64.getEncoder().encodeToString(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));}catch(Exception e){throw new IllegalStateException(e);}}
    public record Issued(String token,Instant expiresAt){}
}
