package net.hivel.islandsrpg.listener;
import net.hivel.islandsrpg.IslandsRPGPlugin; import org.bukkit.event.*; import org.bukkit.event.player.*;
public class PlayerListener implements Listener { private final IslandsRPGPlugin p; public PlayerListener(IslandsRPGPlugin p){this.p=p;} @EventHandler public void join(PlayerJoinEvent e){p.data().load(e.getPlayer());} @EventHandler public void quit(PlayerQuitEvent e){p.data().unload(e.getPlayer());} @EventHandler public void held(PlayerItemHeldEvent e){} }
