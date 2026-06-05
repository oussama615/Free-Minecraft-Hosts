package net.hivel.islandsrpg.gui;
import net.hivel.islandsrpg.IslandsRPGPlugin; import org.bukkit.entity.Player; import org.bukkit.event.inventory.InventoryClickEvent;
public class MainMenuGui { private final IslandsRPGPlugin p; public MainMenuGui(IslandsRPGPlugin p){this.p=p;} public void open(Player player){p.guis().openStatic(player,"main","&8ɪꜱʟᴀɴᴅꜱ ʀᴘɢ");} public void click(InventoryClickEvent e){p.guis().handle(e);} }
