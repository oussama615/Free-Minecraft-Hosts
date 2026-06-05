package net.hivel.islandsrpg.listener;

import net.hivel.islandsrpg.IslandsRPGPlugin;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerItemHeldEvent;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerQuitEvent;

public class PlayerListener implements Listener {
    private final IslandsRPGPlugin plugin;
    public PlayerListener(IslandsRPGPlugin plugin) { this.plugin = plugin; }
    @EventHandler public void join(PlayerJoinEvent event) { plugin.data().load(event.getPlayer()); plugin.questScoreboards().onJoin(event.getPlayer()); }
    @EventHandler public void quit(PlayerQuitEvent event) { plugin.questScoreboards().onQuit(event.getPlayer()); plugin.data().unload(event.getPlayer()); }
    @EventHandler public void held(PlayerItemHeldEvent event) { }
}
