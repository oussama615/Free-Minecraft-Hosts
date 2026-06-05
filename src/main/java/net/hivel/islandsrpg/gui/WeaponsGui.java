package net.hivel.islandsrpg.gui;
import net.hivel.islandsrpg.IslandsRPGPlugin; import org.bukkit.entity.Player;
public class WeaponsGui { private final IslandsRPGPlugin p; public WeaponsGui(IslandsRPGPlugin p){this.p=p;} public void open(Player player){p.guis().openWeapons(player);} }
