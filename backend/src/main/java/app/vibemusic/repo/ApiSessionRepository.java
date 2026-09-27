package app.vibemusic.repo;
import app.vibemusic.model.ApiSession;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.Instant;
import java.util.Optional;
public interface ApiSessionRepository extends JpaRepository<ApiSession, String> {
    @EntityGraph(attributePaths = "user")
    Optional<ApiSession> findByTokenHashAndExpiresAtAfter(String hash, Instant now);
}
