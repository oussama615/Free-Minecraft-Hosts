package net.hivel.islandsrpg.command;

import net.hivel.islandsrpg.IslandsRPGPlugin;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.command.TabCompleter;
import org.bukkit.entity.Player;

import java.util.List;

public class PlayerMenuCommand implements CommandExecutor, TabCompleter {
    private final IslandsRPGPlugin plugin;
    private final MenuType menuType;
    private final String permission;

    public PlayerMenuCommand(IslandsRPGPlugin plugin, MenuType menuType, String permission) {
        this.plugin = plugin;
        this.menuType = menuType;
        this.permission = permission;
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player player)) {
            sender.sendMessage(plugin.theme().apply("&cᴇʀʀᴏʀ&7: players only."));
            return true;
        }
        if (permission != null && !permission.isBlank() && !player.hasPermission(permission)) {
            player.sendMessage(plugin.theme().apply("&cᴇʀʀᴏʀ&7: no permission."));
            return true;
        }
        switch (menuType) {
            case MAIN -> plugin.guis().openMain(player);
            case STATS -> plugin.guis().openStats(player);
            case QUESTS -> plugin.guis().openQuests(player);
            case PROFILE -> plugin.guis().openProfile(player);
            case WEAPONS -> plugin.guis().openWeapons(player);
            case ISLES -> plugin.guis().openIslands(player);
        }
        return true;
    }

    @Override
    public List<String> onTabComplete(CommandSender sender, Command command, String alias, String[] args) {
        return List.of();
    }

    public enum MenuType {
        MAIN,
        STATS,
        QUESTS,
        PROFILE,
        WEAPONS,
        ISLES
    }
}
