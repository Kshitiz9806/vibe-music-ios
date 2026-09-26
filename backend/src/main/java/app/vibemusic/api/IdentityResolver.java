package app.vibemusic.api;
import app.vibemusic.model.UserAccount;
import app.vibemusic.security.SessionIdentity;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Component;
@Component
public class IdentityResolver {
 public SessionIdentity required(HttpServletRequest request){Object value=request.getAttribute("identity");if(value instanceof SessionIdentity identity)return identity;throw new ApiException("UNAUTHORIZED","A valid VibeMusic session is required",401);}
 public UserAccount user(HttpServletRequest request){return required(request).user();}
}
