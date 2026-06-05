package net.hivel.islandsrpg.quest;

import net.hivel.islandsrpg.IslandsRPGPlugin;
import net.hivel.islandsrpg.data.PlayerData;
import net.hivel.islandsrpg.util.ColorUtil;
import net.hivel.islandsrpg.util.ConfigUtil;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.entity.Player;

import java.util.*;

public class QuestService {
    private final IslandsRPGPlugin plugin;
    private final Map<String, Quest> quests = new LinkedHashMap<>();

    public QuestService(IslandsRPGPlugin plugin) { this.plugin = plugin; }

    public void reload() {
        FileConfiguration config = ConfigUtil.load(plugin, "quests.yml");
        quests.clear();
        var section = config.getConfigurationSection("quests");
        if (section == null) return;
        for (String id : section.getKeys(false)) {
            try {
                String path = "quests." + id + ".";
                QuestType type = QuestType.valueOf(config.getString(path + "type", "KILL"));
                quests.put(id, new Quest(id, config.getString(path + "display-name", id), config.getString(path + "island", "starter"), type, config.getString(path + "target", ""), config.getInt(path + "amount", 1), config.getLong(path + "rewards.xp", 0), config.getLong(path + "rewards.money", 0), config.getLong(path + "rewards.fragments", 0), config.getString(path + "next", null), config.getBoolean(path + "repeatable", false), config.getBoolean(path + "daily", false)));
            } catch (Exception e) {
                plugin.getLogger().warning("Invalid quest " + id + ": " + e.getMessage());
            }
        }
    }

    public Collection<Quest> all() { return quests.values(); }
    public Quest get(String id) { return quests.get(id); }

    public boolean start(Player player, String id) {
        Quest quest = get(id);
        if (quest == null) return false;
        PlayerData data = plugin.data().get(player);
        if (data.activeQuests.containsKey(id)) return true;
        if (data.completedQuests.contains(id) && !quest.repeatable()) return false;
        QuestProgress progress = new QuestProgress(id, 0);
        data.activeQuests.put(id, progress);
        player.sendMessage(plugin.placeholders().apply(player, plugin.message("quest-started"), null, quest, progress, "active", null, null));
        plugin.data().save(data);
        plugin.questScoreboards().onQuestStart(player, quest);
        return true;
    }

    public void cancel(Player player, String id) {
        PlayerData data = plugin.data().get(player);
        if (data.activeQuests.remove(id) != null) {
            plugin.data().save(data);
            plugin.questScoreboards().onQuestCancel(player);
        }
    }

    public void complete(Player player, String id) {
        Quest quest = get(id);
        if (quest == null) return;
        PlayerData data = plugin.data().get(player);
        data.activeQuests.remove(id);
        if (!quest.repeatable()) data.completedQuests.add(id);
        plugin.levels().addXp(player, quest.xp());
        plugin.currency().addMoney(player, quest.money());
        plugin.currency().addFragments(player, quest.fragments());
        player.sendMessage(plugin.placeholders().apply(player, plugin.message("quest-complete"), null, quest, new QuestProgress(id, quest.amount()), "completed", null, null));
        plugin.data().save(data);
        plugin.questScoreboards().onQuestComplete(player, quest);
    }

    private void progress(Player player, QuestType type, String target, int amount) {
        PlayerData data = plugin.data().get(player);
        for (QuestProgress progress : new ArrayList<>(data.activeQuests.values())) {
            Quest quest = get(progress.questId());
            if (quest == null || quest.type() != type) continue;
            if (!quest.target().equalsIgnoreCase(target) && type != QuestType.REACH_LEVEL) continue;
            if (type == QuestType.REACH_LEVEL) progress.setCurrent(amount); else progress.add(1);
            plugin.questScoreboards().onQuestProgress(player, quest, progress);
            if (progress.current() >= quest.amount()) complete(player, quest.id());
        }
        plugin.data().save(data);
    }

    public void handleKill(Player player, String mob) { progress(player, QuestType.KILL, mob, 1); }
    public void handleBossKill(Player player, String boss) { progress(player, QuestType.BOSS_KILL, boss, 1); }
    public void handleReachLevel(Player player, int level) { progress(player, QuestType.REACH_LEVEL, "", level); }
    public void handleVisitIsland(Player player, String island) { progress(player, QuestType.VISIT_ISLAND, island, 1); }
}
