package app.vibemusic.repo;
import app.vibemusic.model.RadioSession;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
public interface RadioSessionRepository extends JpaRepository<RadioSession,String>{Optional<RadioSession> findByIdAndUser_Id(String id,String userId);List<RadioSession> findByEndedAtIsNullAndLastActivityAtBefore(Instant before);}
