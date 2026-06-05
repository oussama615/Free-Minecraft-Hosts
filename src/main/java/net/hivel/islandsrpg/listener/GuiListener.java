package net.hivel.islandsrpg.listener;
import net.hivel.islandsrpg.IslandsRPGPlugin; import org.bukkit.event.*; import org.bukkit.event.inventory.InventoryClickEvent;
public class GuiListener implements Listener { private final IslandsRPGPlugin p; public GuiListener(IslandsRPGPlugin p){this.p=p;} @EventHandler public void click(InventoryClickEvent e){p.guis().handle(e);} }
