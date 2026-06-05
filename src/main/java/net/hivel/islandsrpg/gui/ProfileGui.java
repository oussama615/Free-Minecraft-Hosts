package net.hivel.islandsrpg.gui;
import net.hivel.islandsrpg.IslandsRPGPlugin; import org.bukkit.entity.Player;
public class ProfileGui { private final IslandsRPGPlugin p; public ProfileGui(IslandsRPGPlugin p){this.p=p;} public void open(Player player){p.guis().openProfile(player);} }
