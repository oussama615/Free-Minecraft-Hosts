package com.empcontrol.agent.config;
import com.google.gson.Gson;
import javax.crypto.Cipher; import javax.crypto.KeyGenerator; import javax.crypto.SecretKey; import javax.crypto.spec.GCMParameterSpec; import java.io.*; import java.nio.file.*; import java.security.*; import java.util.*;
public final class SecureStore {
  private final Path data; private final Gson gson = new Gson();
  public SecureStore(Path pluginDir) { this.data = pluginDir.resolve("agent.dat"); }
  public Optional<AgentIdentity> load() { try { if (!Files.exists(data)) return Optional.empty(); byte[] raw = Files.readAllBytes(data); byte[] salt = Arrays.copyOfRange(raw,0,16); byte[] iv = Arrays.copyOfRange(raw,16,28); byte[] cipher = Arrays.copyOfRange(raw,28,raw.length); Cipher c = Cipher.getInstance("AES/GCM/NoPadding"); c.init(Cipher.DECRYPT_MODE, key(salt), new GCMParameterSpec(128, iv)); return Optional.of(gson.fromJson(new String(c.doFinal(cipher)), AgentIdentity.class)); } catch (Exception e) { return Optional.empty(); } }
  public void save(AgentIdentity identity) throws Exception { Files.createDirectories(data.getParent()); byte[] salt = random(16), iv = random(12); Cipher c = Cipher.getInstance("AES/GCM/NoPadding"); c.init(Cipher.ENCRYPT_MODE, key(salt), new GCMParameterSpec(128, iv)); byte[] enc = c.doFinal(gson.toJson(identity).getBytes()); ByteArrayOutputStream out = new ByteArrayOutputStream(); out.write(salt); out.write(iv); out.write(enc); Files.write(data, out.toByteArray(), StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING); }
  public void clear() throws IOException { Files.deleteIfExists(data); }
  private SecretKey key(byte[] salt) throws Exception { MessageDigest d = MessageDigest.getInstance("SHA-256"); d.update(System.getProperty("user.name", "emp").getBytes()); d.update(System.getProperty("os.name", "unknown").getBytes()); d.update(salt); return new javax.crypto.spec.SecretKeySpec(d.digest(), "AES"); }
  private byte[] random(int n) { byte[] b = new byte[n]; new SecureRandom().nextBytes(b); return b; }
}
