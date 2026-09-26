package app.vibemusic.config;
import app.vibemusic.security.SessionAuthFilter;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.AnonymousAuthenticationFilter;
@Configuration
public class SecurityConfig {
 @Bean FilterRegistrationBean<SessionAuthFilter> disableContainerRegistration(SessionAuthFilter filter){FilterRegistrationBean<SessionAuthFilter> registration=new FilterRegistrationBean<>(filter);registration.setEnabled(false);return registration;}
 @Bean SecurityFilterChain filterChain(HttpSecurity http,SessionAuthFilter auth) throws Exception {
  return http.csrf(c->c.disable()).headers(h->h.frameOptions(f->f.sameOrigin())).sessionManagement(s->s.sessionCreationPolicy(SessionCreationPolicy.STATELESS)).authorizeHttpRequests(a->a.anyRequest().permitAll()).addFilterBefore(auth,AnonymousAuthenticationFilter.class).build();
 }
}
