package app.vibemusic.repo;
import app.vibemusic.model.PlayHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.Instant;
import java.util.Optional;
import java.util.Set;
public interface PlayHistoryRepository extends JpaRepository<PlayHistory,String>{
 Optional<PlayHistory> findByPlayHistoryId(String id);
 @Query("select distinct h.trackId from PlayHistory h where h.user.id=:userId and h.playedAt>=:since") Set<String> findRecentlyPlayed(@Param("userId") String userId,@Param("since") Instant since);
}
