package app.vibemusic.security;
import app.vibemusic.model.UserAccount;
public record SessionIdentity(UserAccount user,String sessionId) {}
