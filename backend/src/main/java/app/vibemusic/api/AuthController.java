package app.vibemusic.api;

import app.vibemusic.model.UserAccount;
import app.vibemusic.repo.UserRepository;
import app.vibemusic.security.SessionService;
import app.vibemusic.security.TokenCipher;
import app.vibemusic.spotify.SpotifyClient;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.Map;

@RestController @RequestMapping("/auth")
public class AuthController {
 private final SpotifyClient spotify;private final UserRepository users;private final SessionService sessions;private final TokenCipher cipher;private final IdentityResolver identities;
 public AuthController(SpotifyClient spotify,UserRepository users,SessionService sessions,TokenCipher cipher,IdentityResolver identities){this.spotify=spotify;this.users=users;this.sessions=sessions;this.cipher=cipher;this.identities=identities;}
 public record Callback(@NotBlank String code,@NotBlank String redirectUri,@NotBlank String codeVerifier){}
 @PostMapping("/spotify/callback") @Transactional public ResponseEntity<?> callback(@Valid @RequestBody Callback body){
  SpotifyClient.TokenResult token;try{token=spotify.exchangeAndReadProfile(body.code(),body.redirectUri(),body.codeVerifier());}catch(Exception e){throw new ApiException("INVALID_CODE","Spotify authorization code is invalid or expired",401);}
  if(!token.premium())throw new ApiException("PREMIUM_REQUIRED","Spotify Premium is required for on-demand playback",403);
  UserAccount user=users.findBySpotifyUserId(token.spotifyUserId()).orElseGet(()->new UserAccount(token.spotifyUserId(),token.displayName(),true,cipher.encrypt(token.accessToken()),cipher.encrypt(token.refreshToken()),Instant.now().plusSeconds(token.expiresIn())));
  user.updateProfile(token.displayName(),true);user.updateTokens(cipher.encrypt(token.accessToken()),cipher.encrypt(token.refreshToken()),Instant.now().plusSeconds(token.expiresIn()));users.save(user);
  var issued=sessions.issue(user);return ResponseEntity.ok(Map.of("sessionToken",issued.token(),"expiresAt",issued.expiresAt(),"user",Map.of("id",user.getId(),"displayName",user.getDisplayName(),"isPremium",user.isPremium())));
 }
 @PostMapping("/logout") public ResponseEntity<Void> logout(HttpServletRequest request){String token=bearer(request);if(token!=null)sessions.revoke(token);return ResponseEntity.noContent().build();}
 @GetMapping("/session") public ResponseEntity<?> session(HttpServletRequest request){var identity=identities.required(request);return ResponseEntity.ok(Map.of("valid",true,"user",Map.of("id",identity.user().getId(),"displayName",identity.user().getDisplayName())));}
 private String bearer(HttpServletRequest r){String h=r.getHeader("Authorization");return h!=null&&h.startsWith("Bearer ")?h.substring(7):null;}
}
