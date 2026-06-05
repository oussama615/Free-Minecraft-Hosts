package net.hivel.islandsrpg.theme;

import net.hivel.islandsrpg.util.ColorUtil;
import net.hivel.islandsrpg.util.ConfigUtil;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.plugin.java.JavaPlugin;

public class ThemeService {
    private final JavaPlugin plugin;
    private FileConfiguration config;

    public ThemeService(JavaPlugin plugin) {
        this.plugin = plugin;
        reload();
    }

    public void reload() {
        config = ConfigUtil.load(plugin, "theme.yml");
    }

    public String prefix() {
        return config.getString("theme.prefix", "&bɪꜱʟᴀɴᴅꜱ&8 » &7");
    }

    public String color(String key) {
        return config.getString("theme.colors." + key, "&7");
    }

    public String symbol(String key) {
        if (!emojisEnabled()) {
            return switch (key) {
                case "money" -> "$";
                case "arrow" -> "->";
                case "locked" -> "x";
                case "unlocked" -> "+";
                default -> "";
            };
        }
        return config.getString("theme.symbols." + key, "");
    }

    public boolean emojisEnabled() {
        return config.getBoolean("theme.emojis.enabled", true);
    }

    public boolean smallCapsEnabled() {
        return config.getBoolean("theme.small-caps.enabled", true);
    }

    public String apply(String text) {
        if (text == null) return "";
        String out = text;
        for (String key : config.getConfigurationSection("theme.colors") == null ? java.util.Set.<String>of() : config.getConfigurationSection("theme.colors").getKeys(false)) {
            out = out.replace("%color_" + key + "%", color(key));
        }
        for (String key : config.getConfigurationSection("theme.symbols") == null ? java.util.Set.<String>of() : config.getConfigurationSection("theme.symbols").getKeys(false)) {
            out = out.replace("%symbol_" + key + "%", symbol(key));
        }
        if (!emojisEnabled()) {
            out = ColorUtil.stripEmojis(out);
        }
        return ColorUtil.color(out);
    }
}
