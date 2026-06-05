package net.hivel.islandsrpg.gui;
import net.hivel.islandsrpg.IslandsRPGPlugin; import org.bukkit.entity.Player; import org.bukkit.event.inventory.InventoryClickEvent;
public class QuestsGui { private final IslandsRPGPlugin p; public QuestsGui(IslandsRPGPlugin p){this.p=p;} public void open(Player player){p.guis().openQuests(player);} public void click(InventoryClickEvent e){p.guis().handle(e);} }
