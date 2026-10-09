package app.vibemusic.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.Arrays;
import java.util.List;

@Configuration
public class WebCorsConfig {
    @Bean
    WebMvcConfigurer webCorsConfigurer(@Value("${vibemusic.web.allowed-origins:http://127.0.0.1:5173}") String allowedOrigins) {
        List<String> origins = Arrays.stream(allowedOrigins.split(",")).map(String::trim).filter(s -> !s.isEmpty()).toList();
        return new WebMvcConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                registry.addMapping("/**").allowedOrigins(origins.toArray(String[]::new))
                        .allowedMethods("GET", "POST", "PUT", "OPTIONS")
                        .allowedHeaders("Authorization", "Content-Type", "Accept")
                        .allowCredentials(true).maxAge(3600);
            }
        };
    }
}
