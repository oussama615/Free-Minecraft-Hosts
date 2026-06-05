package net.hivel.islandsrpg.scoreboard;

import net.hivel.islandsrpg.IslandsRPGPlugin;
import net.hivel.islandsrpg.data.PlayerData;
import net.hivel.islandsrpg.quest.Quest;
import net.hivel.islandsrpg.quest.QuestProgress;
import org.bukkit.Bukkit;
import org.bukkit.ChatColor;
import org.bukkit.entity.Player;
import org.bukkit.scheduler.BukkitTask;
import org.bukkit.scoreboard.DisplaySlot;
import org.bukkit.scoreboard.Objective;
import org.bukkit.scoreboard.Scoreboard;
import org.bukkit.scoreboard.ScoreboardManager;

import java.util.*;

public class QuestScoreboardService {
    private final IslandsRPGPlugin plugin;
    private final Map<UUID, Scoreboard> previous = new HashMap<>();
    private final Set<UUID> managed = new HashSet<>();
    private BukkitTask task;
    private final Set<String> warnedLines = new HashSet<>();

    public QuestScoreboardService(IslandsRPGPlugin plugin) {
        this.plugin = plugin;
    }

    public void start() {
        stopTask();
        if (!plugin.scoreboardConfig().enabled()) return;
        task = plugin.getServer().getScheduler().runTaskTimer(plugin, () -> {
            for (Player player : plugin.getServer().getOnlinePlayers()) {
                update(player);
            }
        }, 20L, plugin.scoreboardConfig().updateIntervalTicks());
    }

    public void reload() {
        plugin.scoreboardConfig().reload();
        warnedLines.clear();
        start();
        for (Player player : plugin.getServer().getOnlinePlayers()) update(player);
    }

    public void stopTask() {
        if (task != null) task.cancel();
        task = null;
    }

    public void onJoin(Player player) {
        if (plugin.scoreboardConfig().enabled()) update(player);
    }

    public void onQuit(Player player) {
        restore(player);
    }

    public void disable() {
        stopTask();
        if (plugin.scoreboardConfig().clearOnDisable()) {
            for (Player player : Bukkit.getOnlinePlayers()) restore(player);
        }
        previous.clear();
        managed.clear();
    }

    public void onQuestStart(Player player, Quest quest) {
        update(player, quest, plugin.data().get(player).activeQuests.get(quest.id()), "active");
    }

    public void onQuestProgress(Player player, Quest quest, QuestProgress progress) {
        update(player, quest, progress, "active");
    }

    public void onQuestCancel(Player player) {
        update(player);
    }

    public void onQuestComplete(Player player, Quest quest) {
        if (!plugin.scoreboardConfig().enabled()) return;
        if (plugin.scoreboardConfig().completedEnabled()) {
            render(player, plugin.scoreboardConfig().completedTitle(), plugin.scoreboardConfig().completedLines(), quest, new QuestProgress(quest.id(), quest.amount()), "completed");
            plugin.getServer().getScheduler().runTaskLater(plugin, () -> update(player), plugin.scoreboardConfig().completedDurationTicks());
        } else {
            update(player);
        }
    }

    public void update(Player player) {
        if (!plugin.scoreboardConfig().enabled()) { restore(player); return; }
        PlayerData data = plugin.data().get(player);
        QuestProgress first = data.activeQuests.values().stream().findFirst().orElse(null);
        Quest quest = first == null ? null : plugin.quests().get(first.questId());
        if (quest != null) {
            update(player, quest, first, "active");
            return;
        }
        if (plugin.scoreboardConfig().onlyShowWhenActiveQuest() && !plugin.scoreboardConfig().noActiveEnabled()) {
            restore(player);
            return;
        }
        if (plugin.scoreboardConfig().noActiveEnabled()) {
            render(player, plugin.scoreboardConfig().noActiveTitle(), plugin.scoreboardConfig().noActiveLines(), null, null, "none");
        }
    }

    private void update(Player player, Quest quest, QuestProgress progress, String status) {
        render(player, plugin.scoreboardConfig().title(), plugin.scoreboardConfig().lines(), quest, progress, status);
    }

    private void render(Player player, String title, List<String> lines, Quest quest, QuestProgress progress, String status) {
        ScoreboardManager manager = Bukkit.getScoreboardManager();
        if (manager == null) return;
        if (!managed.contains(player.getUniqueId()) && plugin.scoreboardConfig().restorePrevious()) {
            previous.put(player.getUniqueId(), player.getScoreboard());
        }
        Scoreboard board = manager.getNewScoreboard();
        Objective objective = board.registerNewObjective("islandsrpg", "dummy", trim(plugin.theme().apply(title), 128));
        objective.setDisplaySlot(DisplaySlot.SIDEBAR);
        int score = Math.min(lines.size(), 15);
        for (int i = 0; i < lines.size() && i < 15; i++) {
            String raw = lines.get(i);
            if (raw == null) continue;
            String parsed = plugin.placeholders().apply(player, raw, null, quest, progress, status, null, null);
            parsed = trim(parsed, 128);
            String entry = unique(parsed, i);
            objective.getScore(entry).setScore(score--);
        }
        player.setScoreboard(board);
        managed.add(player.getUniqueId());
    }

    private String unique(String line, int index) {
        String suffix = ChatColor.values()[Math.min(index, ChatColor.values().length - 1)].toString();
        String out = line + suffix;
        if (out.length() > 128) out = out.substring(0, 128);
        return out;
    }

    private String trim(String line, int max) {
        if (line.length() <= max) return line;
        String key = line.substring(0, Math.min(24, line.length()));
        if (warnedLines.add(key)) plugin.getLogger().warning("Scoreboard line too long; trimming: " + key);
        return line.substring(0, max);
    }

    private void restore(Player player) {
        if (!managed.remove(player.getUniqueId())) return;
        Scoreboard old = previous.remove(player.getUniqueId());
        ScoreboardManager manager = Bukkit.getScoreboardManager();
        player.setScoreboard(old != null ? old : manager == null ? player.getScoreboard() : manager.getMainScoreboard());
    }
}
