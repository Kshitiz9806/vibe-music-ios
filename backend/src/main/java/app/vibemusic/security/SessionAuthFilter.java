package app.vibemusic.security;

import app.vibemusic.model.ApiSession;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;

@Component
public class SessionAuthFilter extends OncePerRequestFilter {
    private final SessionService sessions;
    public SessionAuthFilter(SessionService sessions){this.sessions=sessions;}
    @Override protected boolean shouldNotFilter(HttpServletRequest request){return request.getRequestURI().startsWith("/auth/spotify/callback")||request.getRequestURI().startsWith("/swagger")||request.getRequestURI().startsWith("/v3/api-docs")||request.getRequestURI().startsWith("/h2-console");}
    @Override protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain)throws ServletException,IOException{
        String header=request.getHeader("Authorization");
        if(header!=null&&header.startsWith("Bearer ")){ApiSession session=sessions.find(header.substring(7));if(session!=null)request.setAttribute("identity",new SessionIdentity(session.getUser(),session.getId()));}
        chain.doFilter(request,response);
    }
}
