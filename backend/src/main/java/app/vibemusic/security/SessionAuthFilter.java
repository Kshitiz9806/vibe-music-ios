package app.vibemusic.security;

import app.vibemusic.model.ApiSession;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.Cookie;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

@Component
public class SessionAuthFilter extends OncePerRequestFilter {
    public static final String SESSION_COOKIE = "VibeMusicSession";
    private final SessionService sessions;
    private final Set<String> allowedOrigins;
    public SessionAuthFilter(SessionService sessions,@Value("${vibemusic.web.allowed-origins:http://127.0.0.1:5173}") String configuredOrigins){this.sessions=sessions;this.allowedOrigins=Arrays.stream(configuredOrigins.split(",")).map(String::trim).filter(s->!s.isEmpty()).collect(Collectors.toUnmodifiableSet());}
    @Override protected boolean shouldNotFilter(HttpServletRequest request){return request.getRequestURI().startsWith("/auth/spotify/callback")||request.getRequestURI().startsWith("/swagger")||request.getRequestURI().startsWith("/v3/api-docs")||request.getRequestURI().startsWith("/h2-console");}
    @Override protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain)throws ServletException,IOException{
        String token=null;
        String header=request.getHeader("Authorization");
        if(header!=null&&header.startsWith("Bearer ")) token=header.substring(7);
        boolean cookieAuth=false;
        if(token==null&&request.getCookies()!=null) for(Cookie cookie:request.getCookies()) if(SESSION_COOKIE.equals(cookie.getName())) { token=cookie.getValue(); cookieAuth=true; break; }
        if(cookieAuth&&isStateChanging(request.getMethod())) {
            String origin=request.getHeader("Origin");
            if(origin==null||!allowedOrigins.contains(origin)){response.sendError(HttpServletResponse.SC_FORBIDDEN,"Request origin is not allowed");return;}
        }
        if(token!=null){ApiSession session=sessions.find(token);if(session!=null)request.setAttribute("identity",new SessionIdentity(session.getUser(),session.getId()));}
        chain.doFilter(request,response);
    }
    private boolean isStateChanging(String method){return !"GET".equalsIgnoreCase(method)&&!"HEAD".equalsIgnoreCase(method)&&!"OPTIONS".equalsIgnoreCase(method);}
}
