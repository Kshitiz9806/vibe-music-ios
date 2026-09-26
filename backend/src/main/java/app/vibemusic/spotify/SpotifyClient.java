package app.vibemusic.spotify;

import app.vibemusic.model.UserAccount;
import app.vibemusic.repo.UserRepository;
import app.vibemusic.security.TokenCipher;
import tools.jackson.databind.JsonNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;

@Component
public class SpotifyClient {
    private final RestClient api,accounts; private final String clientId,clientSecret; private final UserRepository users; private final TokenCipher cipher;
    private final Object rateLock=new Object(); private final long requestIntervalNanos; private long nextRequestNanos;
    public SpotifyClient(@Value("${spotify.api-base-url}") String apiUrl,@Value("${spotify.accounts-base-url}") String accountsUrl,@Value("${spotify.client-id:}") String clientId,@Value("${spotify.client-secret:}") String clientSecret,@Value("${spotify.requests-per-second:3}") double requestsPerSecond,UserRepository users,TokenCipher cipher){this.api=RestClient.builder().baseUrl(apiUrl).build();this.accounts=RestClient.builder().baseUrl(accountsUrl).build();this.clientId=clientId;this.clientSecret=clientSecret;this.users=users;this.cipher=cipher;this.requestIntervalNanos=(long)(1_000_000_000d/Math.max(0.1,requestsPerSecond));}
    public JsonNode exchangeCode(String code,String redirectUri,String codeVerifier){var form=new LinkedMultiValueMap<String,String>();form.add("grant_type","authorization_code");form.add("code",code);form.add("redirect_uri",redirectUri);if(codeVerifier!=null&&!codeVerifier.isBlank())form.add("code_verifier",codeVerifier);return accounts.post().uri("/api/token").contentType(MediaType.APPLICATION_FORM_URLENCODED).header("Authorization",basic()).body(form).retrieve().body(JsonNode.class);}
    public JsonNode refresh(String refreshToken){var form=new LinkedMultiValueMap<String,String>();form.add("grant_type","refresh_token");form.add("refresh_token",refreshToken);return accounts.post().uri("/api/token").contentType(MediaType.APPLICATION_FORM_URLENCODED).header("Authorization",basic()).body(form).retrieve().body(JsonNode.class);}
    public JsonNode get(String path,UserAccount user){throttle();return api.get().uri(path).headers(h->h.setBearerAuth(accessToken(user))).retrieve().body(JsonNode.class);}
    public JsonNode get(String path,Map<String,Object> query,UserAccount user){throttle();return api.get().uri(uri->{var b=uri.path(path);query.forEach((k,v)->b.queryParam(k,v));return b.build();}).headers(h->h.setBearerAuth(accessToken(user))).retrieve().body(JsonNode.class);}
    public String accessToken(UserAccount user){if(user.getTokenExpiresAt().isAfter(Instant.now().plusSeconds(60)))return cipher.decrypt(user.getAccessToken());synchronized(user){if(user.getTokenExpiresAt().isAfter(Instant.now().plusSeconds(60)))return cipher.decrypt(user.getAccessToken());JsonNode refreshed=refresh(cipher.decrypt(user.getEncryptedRefreshToken()));String access=refreshed.path("access_token").asText();String newRefresh=refreshed.hasNonNull("refresh_token")?refreshed.path("refresh_token").asText():null;user.updateTokens(cipher.encrypt(access),newRefresh==null?null:cipher.encrypt(newRefresh),Instant.now().plusSeconds(refreshed.path("expires_in").asLong(3600)));users.save(user);return access;}}
    public TokenResult exchangeAndReadProfile(String code,String redirectUri,String codeVerifier){JsonNode token=exchangeCode(code,redirectUri,codeVerifier);String access=token.path("access_token").asText();if(access.isBlank())throw new IllegalArgumentException("Spotify did not return an access token");JsonNode me=api.get().uri("/me").headers(h->h.setBearerAuth(access)).retrieve().body(JsonNode.class);boolean premium="premium".equalsIgnoreCase(me.path("product").asText());return new TokenResult(me.path("id").asText(),me.path("display_name").asText(me.path("id").asText()),premium,access,token.path("refresh_token").asText(),token.path("expires_in").asLong(3600));}
    private String basic(){return "Basic "+Base64.getEncoder().encodeToString((clientId+":"+clientSecret).getBytes(StandardCharsets.UTF_8));}
    private void throttle(){long wait;synchronized(rateLock){long now=System.nanoTime();wait=Math.max(0,nextRequestNanos-now);nextRequestNanos=Math.max(now,nextRequestNanos)+requestIntervalNanos;}if(wait>0)try{long millis=wait/1_000_000L;int nanos=(int)(wait%1_000_000L);Thread.sleep(millis,nanos);}catch(InterruptedException e){Thread.currentThread().interrupt();throw new IllegalStateException("Interrupted while waiting for Spotify rate limit",e);}}
    public record TokenResult(String spotifyUserId,String displayName,boolean premium,String accessToken,String refreshToken,long expiresIn){}
}
