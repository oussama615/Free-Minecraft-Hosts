package com.empcontrol.agent.listener;

import com.empcontrol.agent.net.AgentClient;
import org.bukkit.Bukkit;
import org.bukkit.OfflinePlayer;
import org.bukkit.command.CommandSender;
import org.bukkit.event.Cancellable;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerCommandPreprocessEvent;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.server.ServerCommandEvent;
import org.bukkit.plugin.Plugin;

import java.util.HashSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

public final class SecurityListener implements Listener {
  private final Plugin plugin;
  private final AgentClient client;
  private final Set<String> dangerous = Set.of("op", "deop", "stop", "restart", "reload", "rl", "plugins", "pl", "ver", "version", "luckperms", "lp", "pex", "permissions", "gamemode", "give", "effect", "pardon", "ban", "unban", "plugman");
  private final Set<String> protectedOps = new HashSet<>();
  private volatile boolean panic;

  public SecurityListener(Plugin plugin, AgentClient client) {
    this.plugin = plugin;
    this.client = client;
    for (OfflinePlayer op : Bukkit.getOperators()) protectedOps.add(op.getUniqueId().toString());
  }

  public void panic(boolean enabled, CommandSender actor) {
    panic = enabled;
    client.send("securityEvent", Map.of("type", "PANIC_MODE", "actor", actor.getName(), "action", enabled ? "enabled" : "disabled", "title", "Panic mode " + (enabled ? "enabled" : "disabled")));
    if (enabled) enforceOps("panic", actor.getName());
  }

  @EventHandler
  public void onPlayerCommand(PlayerCommandPreprocessEvent event) {
    inspect(event.getPlayer(), event.getMessage().substring(1), event);
  }

  @EventHandler
  public void onServerCommand(ServerCommandEvent event) {
    inspect(event.getSender(), event.getCommand(), event);
  }

  @EventHandler
  public void onJoin(PlayerJoinEvent event) {
    if (event.getPlayer().isOp()) enforceOps("join", event.getPlayer().getName());
  }

  private void inspect(CommandSender sender, String raw, Cancellable event) {
    String lower = raw.toLowerCase(Locale.ROOT).trim();
    String root = lower.split("\\s+")[0];
    boolean dangerousCommand = dangerous.contains(root) || lower.startsWith("whitelist off") || lower.startsWith("spark profiler start");
    if (!dangerousCommand) return;

    boolean blocked = panic || root.equals("op");
    client.send("securityEvent", Map.of("type", "DANGEROUS_COMMAND", "actor", sender.getName(), "subject", raw, "action", blocked ? "blocked" : "observed", "title", "Dangerous command used"));
    if (blocked) {
      event.setCancelled(true);
      sender.sendMessage("§cEMP Control blocked this command for security review.");
    }
    Bukkit.getScheduler().runTaskLater(plugin, () -> enforceOps("command:" + root, sender.getName()), 1L);
  }

  private void enforceOps(String reason, String actor) {
    for (OfflinePlayer op : Bukkit.getOperators()) {
      if (protectedOps.contains(op.getUniqueId().toString())) continue;
      op.setOp(false);
      client.send("securityEvent", Map.of("type", "UNAUTHORIZED_OP", "actor", actor, "subject", String.valueOf(op.getName()), "uuid", op.getUniqueId().toString(), "action", "auto_deop", "reason", reason, "title", "Unauthorized OP removed"));
    }
  }
}
