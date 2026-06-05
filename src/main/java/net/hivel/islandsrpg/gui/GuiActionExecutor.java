package net.hivel.islandsrpg.gui;

import net.hivel.islandsrpg.IslandsRPGPlugin;
import net.hivel.islandsrpg.stats.StatType;
import net.hivel.islandsrpg.util.ColorUtil;
import org.bukkit.Bukkit;
import org.bukkit.entity.Player;

public class GuiActionExecutor {
    private final IslandsRPGPlugin plugin;

    public GuiActionExecutor(IslandsRPGPlugin plugin) {
        this.plugin = plugin;
    }

    public void execute(Player player, GuiAction action) {
        if (action == null) return;
        switch (action.type()) {
            case OPEN_MAIN, BACK -> plugin.guis().openMain(player);
            case OPEN_STATS -> plugin.guis().openStats(player);
            case OPEN_ISLANDS -> plugin.guis().openIslands(player);
            case OPEN_QUESTS -> plugin.guis().openQuests(player);
            case OPEN_PROFILE -> plugin.guis().openProfile(player);
            case OPEN_WEAPONS -> plugin.guis().openWeapons(player);
            case CLOSE -> player.closeInventory();
            case STAT_ADD -> addStat(player, action.first(), action.second());
            case STAT_INFO -> player.sendMessage(plugin.theme().apply(plugin.theme().prefix() + action.first().toLowerCase() + " improves your power."));
            case ISLAND_TELEPORT -> plugin.islands().visit(player, action.first());
            case QUEST_START -> { plugin.quests().start(player, action.first()); plugin.guis().openQuests(player); }
            case QUEST_CANCEL -> { plugin.quests().cancel(player, action.first()); plugin.guis().openQuests(player); }
            case WEAPON_PREVIEW -> player.sendMessage(plugin.theme().apply(plugin.theme().prefix() + "weapon preview: &f" + action.first()));
            case COMMAND -> Bukkit.dispatchCommand(player, action.first());
            case PLAYER_COMMAND -> player.performCommand(action.first());
            case CONSOLE_COMMAND -> Bukkit.dispatchCommand(Bukkit.getConsoleSender(), action.first().replace("%player%", player.getName()));
            case NONE -> { }
        }
    }

    private void addStat(Player player, String statName, String amountRaw) {
        StatType type = StatType.fromKey(statName);
        int amount;
        try { amount = Integer.parseInt(amountRaw); } catch (Exception e) { amount = 1; }
        if (type == null) {
            plugin.getLogger().warning("Invalid stat GUI action: " + statName);
            return;
        }
        if (!plugin.stats().spend(player, type, amount)) {
            player.sendMessage(ColorUtil.color(plugin.message("not-enough-points")));
        }
        plugin.guis().openStats(player);
    }
}
