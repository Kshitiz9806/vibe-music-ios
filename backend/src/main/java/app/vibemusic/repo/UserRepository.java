package app.vibemusic.repo;
import app.vibemusic.model.UserAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface UserRepository extends JpaRepository<UserAccount,String>{Optional<UserAccount> findBySpotifyUserId(String id);}
