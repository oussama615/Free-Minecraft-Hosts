package net.hivel.islandsrpg.command;

import net.hivel.islandsrpg.IslandsRPGPlugin;

public class CommandManager {
    public CommandManager(IslandsRPGPlugin plugin) {
        IslandsCommand islandsCommand = new IslandsCommand(plugin);
        register(plugin, "islands", islandsCommand, islandsCommand);
        registerMenu(plugin, "stats", PlayerMenuCommand.MenuType.STATS, "islands.command.stats");
        registerMenu(plugin, "quests", PlayerMenuCommand.MenuType.QUESTS, "islands.command.quests");
        registerMenu(plugin, "profile", PlayerMenuCommand.MenuType.PROFILE, "islands.command.profile");
        registerMenu(plugin, "weapons", PlayerMenuCommand.MenuType.WEAPONS, "islands.command.weapons");
        registerMenu(plugin, "isles", PlayerMenuCommand.MenuType.ISLES, "islands.command.isles");
    }

    private void registerMenu(IslandsRPGPlugin plugin, String command, PlayerMenuCommand.MenuType type, String permission) {
        PlayerMenuCommand executor = new PlayerMenuCommand(plugin, type, permission);
        register(plugin, command, executor, executor);
    }

    private void register(IslandsRPGPlugin plugin, String command, org.bukkit.command.CommandExecutor executor, org.bukkit.command.TabCompleter completer) {
        var pluginCommand = plugin.getCommand(command);
        if (pluginCommand != null) {
            pluginCommand.setExecutor(executor);
            pluginCommand.setTabCompleter(completer);
        } else {
            plugin.getLogger().warning("Command not registered in plugin.yml: " + command);
        }
    }
}
