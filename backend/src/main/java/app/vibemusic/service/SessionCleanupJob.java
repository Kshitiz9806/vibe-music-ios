package app.vibemusic.service;
import app.vibemusic.model.RadioSession;
import app.vibemusic.repo.RadioSessionRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import java.time.Duration;
import java.time.Instant;
@Component
public class SessionCleanupJob {
 private final RadioSessionRepository sessions;private final Duration idle;
 public SessionCleanupJob(RadioSessionRepository sessions,@Value("${vibemusic.idle-session-window:PT75M}") Duration idle){this.sessions=sessions;this.idle=idle;}
 @Scheduled(fixedDelayString="${vibemusic.cleanup-interval:PT10M}") @Transactional public void cleanup(){for(RadioSession session:sessions.findByEndedAtIsNullAndLastActivityAtBefore(Instant.now().minus(idle)))session.end();}
}
