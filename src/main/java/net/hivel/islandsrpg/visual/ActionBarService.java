package net.hivel.islandsrpg.visual;

import net.hivel.islandsrpg.IslandsRPGPlugin;
import net.md_5.bungee.api.ChatMessageType;
import net.md_5.bungee.api.chat.TextComponent;
import org.bukkit.entity.Player;
import org.bukkit.scheduler.BukkitTask;

public class ActionBarService {
    private final IslandsRPGPlugin plugin;
    private BukkitTask task;

    public ActionBarService(IslandsRPGPlugin plugin) { this.plugin = plugin; }

    public void start() {
        stop();
        if (!plugin.getConfig().getBoolean("actionbar.enabled", true)) return;
        long interval = plugin.getConfig().getLong("actionbar.interval-ticks", 40);
        task = plugin.getServer().getScheduler().runTaskTimer(plugin, () -> {
            for (Player player : plugin.getServer().getOnlinePlayers()) {
                String format = plugin.emojis() ? plugin.getConfig().getString("actionbar.format") : plugin.getConfig().getString("actionbar.format-no-emojis");
                player.spigot().sendMessage(ChatMessageType.ACTION_BAR, TextComponent.fromLegacyText(plugin.placeholders().apply(player, format)));
            }
        }, interval, interval);
    }

    public void stop() { if (task != null) task.cancel(); }
}
