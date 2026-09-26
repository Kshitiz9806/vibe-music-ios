package app.vibemusic.repo;
import app.vibemusic.model.ApiSession;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.Instant;
import java.util.Optional;
public interface ApiSessionRepository extends JpaRepository<ApiSession,String>{Optional<ApiSession> findByTokenHashAndExpiresAtAfter(String hash,Instant now);}
