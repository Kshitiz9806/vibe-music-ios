package app.vibemusic.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.SecureRandom;
import java.util.Base64;

@Component
public class TokenCipher {
    private final byte[] key;
    private final SecureRandom random=new SecureRandom();
    public TokenCipher(@Value("${spotify.token-encryption-key:}") String configured) {
        if(configured==null||configured.isBlank()) { this.key=new byte[32]; new SecureRandom().nextBytes(this.key); }
        else {byte[] decoded=Base64.getDecoder().decode(configured);if(decoded.length!=32)throw new IllegalArgumentException("TOKEN_ENCRYPTION_KEY must decode to exactly 32 bytes");this.key=decoded;}
    }
    public String encrypt(String value){try{byte[] nonce=new byte[12];random.nextBytes(nonce);Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,new SecretKeySpec(key,"AES"),new GCMParameterSpec(128,nonce));byte[] encrypted=cipher.doFinal(value.getBytes(java.nio.charset.StandardCharsets.UTF_8));byte[] result=new byte[nonce.length+encrypted.length];System.arraycopy(nonce,0,result,0,nonce.length);System.arraycopy(encrypted,0,result,nonce.length,encrypted.length);return Base64.getEncoder().encodeToString(result);}catch(Exception e){throw new IllegalStateException("Token encryption failed",e);}}
    public String decrypt(String value){try{byte[] all=Base64.getDecoder().decode(value);byte[] nonce=java.util.Arrays.copyOfRange(all,0,12);byte[] encrypted=java.util.Arrays.copyOfRange(all,12,all.length);Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,new SecretKeySpec(key,"AES"),new GCMParameterSpec(128,nonce));return new String(cipher.doFinal(encrypted),java.nio.charset.StandardCharsets.UTF_8);}catch(Exception e){throw new IllegalStateException("Token decryption failed",e);}}
}
