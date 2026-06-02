package com.empcontrol.agent.security;
import javax.crypto.Mac; import javax.crypto.spec.SecretKeySpec; import java.nio.charset.StandardCharsets; import java.security.MessageDigest; import java.util.Base64;
public final class MessageSigner {
  public static String derivedSecret(String rawSecret) { try { MessageDigest d=MessageDigest.getInstance("SHA-256"); byte[] h=d.digest(rawSecret.getBytes(StandardCharsets.UTF_8)); StringBuilder sb=new StringBuilder(); for(byte b:h) sb.append(String.format("%02x", b)); return sb.toString(); } catch(Exception e){ throw new IllegalStateException(e); } }
  public static String sign(String secret, String canonical) { try { Mac mac=Mac.getInstance("HmacSHA256"); mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256")); return Base64.getUrlEncoder().withoutPadding().encodeToString(mac.doFinal(canonical.getBytes(StandardCharsets.UTF_8))); } catch(Exception e){ throw new IllegalStateException(e); } }
}
