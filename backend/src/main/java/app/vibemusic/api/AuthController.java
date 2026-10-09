package app.vibemusic.api;

import app.vibemusic.model.UserAccount;
import app.vibemusic.repo.UserRepository;
import app.vibemusic.security.SessionService;
import app.vibemusic.security.SessionAuthFilter;
import app.vibemusic.security.TokenCipher;
import app.vibemusic.spotify.SpotifyClient;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseCookie;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.time.Duration;
import java.util.Map;

@RestController @RequestMapping("/auth")
public class AuthController {
 private final SpotifyClient spotify;private final UserRepository users;private final SessionService sessions;private final TokenCipher cipher;private final IdentityResolver identities;private final Duration sessionLifetime;private final boolean secureCookie;
 public AuthController(SpotifyClient spotify,UserRepository users,SessionService sessions,TokenCipher cipher,IdentityResolver identities,@org.springframework.beans.factory.annotation.Value("${vibemusic.session-lifetime:P7D}") Duration sessionLifetime,@org.springframework.beans.factory.annotation.Value("${vibemusic.web.cookie-secure:true}") boolean secureCookie){this.spotify=spotify;this.users=users;this.sessions=sessions;this.cipher=cipher;this.identities=identities;this.sessionLifetime=sessionLifetime;this.secureCookie=secureCookie;}
 public record Callback(@NotBlank String code,@NotBlank String redirectUri,@NotBlank String codeVerifier){}
 @PostMapping("/spotify/callback") @Transactional public ResponseEntity<?> callback(@Valid @RequestBody Callback body,HttpServletRequest request){
  SpotifyClient.TokenResult token;try{token=spotify.exchangeAndReadProfile(body.code(),body.redirectUri(),body.codeVerifier());}catch(Exception e){throw new ApiException("INVALID_CODE","Spotify authorization code is invalid or expired",401);}
  if(!token.premium())throw new ApiException("PREMIUM_REQUIRED","Spotify Premium is required for on-demand playback",403);
  UserAccount user=users.findBySpotifyUserId(token.spotifyUserId()).orElseGet(()->new UserAccount(token.spotifyUserId(),token.displayName(),true,cipher.encrypt(token.accessToken()),cipher.encrypt(token.refreshToken()),Instant.now().plusSeconds(token.expiresIn())));
  user.updateProfile(token.displayName(),true);user.updateTokens(cipher.encrypt(token.accessToken()),cipher.encrypt(token.refreshToken()),Instant.now().plusSeconds(token.expiresIn()));users.save(user);
  var issued=sessions.issue(user);
  boolean browser=request.getHeader("Origin")!=null;
  ResponseCookie cookie=ResponseCookie.from(SessionAuthFilter.SESSION_COOKIE,issued.token()).httpOnly(true).secure(secureCookie).sameSite("Lax").path("/").maxAge(sessionLifetime).build();
  Map<String,Object> profile=Map.of("id",user.getId(),"displayName",user.getDisplayName(),"isPremium",user.isPremium());
  Map<String,Object> response=!browser
          ?Map.of("sessionToken",issued.token(),"expiresAt",issued.expiresAt(),"user",profile)
          :Map.of("expiresAt",issued.expiresAt(),"user",profile);
  var result=ResponseEntity.ok();
  if(browser)result.header(HttpHeaders.SET_COOKIE,cookie.toString());
  return result.body(response);
 }
 @GetMapping("/spotify/playback-token") public ResponseEntity<?> playbackToken(HttpServletRequest request){String token=spotify.accessToken(identities.user(request));return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(Map.of("accessToken",token));}
 @PostMapping("/logout") public ResponseEntity<Void> logout(HttpServletRequest request){String token=bearer(request);if(token==null&&request.getCookies()!=null)for(var cookie:request.getCookies())if(SessionAuthFilter.SESSION_COOKIE.equals(cookie.getName())){token=cookie.getValue();break;}if(token!=null)sessions.revoke(token);ResponseCookie expired=ResponseCookie.from(SessionAuthFilter.SESSION_COOKIE,"").httpOnly(true).secure(secureCookie).sameSite("Lax").path("/").maxAge(Duration.ZERO).build();return ResponseEntity.noContent().header(HttpHeaders.SET_COOKIE,expired.toString()).build();}
 @GetMapping("/session") public ResponseEntity<?> session(HttpServletRequest request){var identity=identities.required(request);return ResponseEntity.ok(Map.of("valid",true,"user",Map.of("id",identity.user().getId(),"displayName",identity.user().getDisplayName())));}
 private String bearer(HttpServletRequest r){String h=r.getHeader("Authorization");return h!=null&&h.startsWith("Bearer ")?h.substring(7):null;}
}
