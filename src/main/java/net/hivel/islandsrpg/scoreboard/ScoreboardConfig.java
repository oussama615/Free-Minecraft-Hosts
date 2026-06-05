package net.hivel.islandsrpg.scoreboard;

import net.hivel.islandsrpg.quest.QuestType;
import net.hivel.islandsrpg.util.ConfigUtil;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.plugin.java.JavaPlugin;

import java.util.List;

public class ScoreboardConfig {
    private final JavaPlugin plugin;
    private FileConfiguration config;
    private boolean broken;

    public ScoreboardConfig(JavaPlugin plugin) {
        this.plugin = plugin;
        reload();
    }

    public void reload() {
        try {
            config = ConfigUtil.load(plugin, "scoreboard.yml");
            broken = false;
        } catch (Exception e) {
            broken = true;
            plugin.getLogger().warning("scoreboard.yml is broken; scoreboard disabled: " + e.getMessage());
        }
    }

    public boolean enabled() { return !broken && config.getBoolean("scoreboard.enabled", true); }
    public boolean onlyShowWhenActiveQuest() { return config.getBoolean("scoreboard.only-show-when-active-quest", true); }
    public long updateIntervalTicks() { return Math.max(5, config.getLong("scoreboard.update-interval-ticks", 20)); }
    public String title() { return config.getString("scoreboard.title", "&b&lɪꜱʟᴀɴᴅꜱ ʀᴘɢ"); }
    public List<String> lines() { return config.getStringList("scoreboard.lines"); }
    public boolean noActiveEnabled() { return config.getBoolean("scoreboard.no-active-quest.enabled", false); }
    public String noActiveTitle() { return config.getString("scoreboard.no-active-quest.title", title()); }
    public List<String> noActiveLines() { return config.getStringList("scoreboard.no-active-quest.lines"); }
    public boolean completedEnabled() { return config.getBoolean("scoreboard.completed-quest-display.enabled", true); }
    public int completedDurationTicks() { return config.getInt("scoreboard.completed-quest-display.duration-ticks", 80); }
    public String completedTitle() { return config.getString("scoreboard.completed-quest-display.title", "&a&lǫᴜᴇꜱᴛ ᴄᴏᴍᴘʟᴇᴛᴇ"); }
    public List<String> completedLines() { return config.getStringList("scoreboard.completed-quest-display.lines"); }
    public boolean restorePrevious() { return config.getBoolean("scoreboard.conflict-handling.restore-previous-scoreboard", true); }
    public boolean clearOnDisable() { return config.getBoolean("scoreboard.conflict-handling.clear-on-disable", true); }
    public String objectiveFormat(QuestType type) { return config.getString("objective-formats." + type.name(), type.name() + " %quest_target% %quest_amount%"); }
}
