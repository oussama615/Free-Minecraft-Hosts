package net.hivel.islandsrpg.gui;

import net.hivel.islandsrpg.IslandsRPGPlugin;
import net.hivel.islandsrpg.util.ConfigUtil;
import org.bukkit.Material;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.configuration.file.FileConfiguration;

import java.util.*;

public class GuiConfig {
    private final IslandsRPGPlugin plugin;
    private FileConfiguration config;
    private final Set<String> warnings = new HashSet<>();

    public GuiConfig(IslandsRPGPlugin plugin) { this.plugin = plugin; reload(); }
    public void reload() { config = ConfigUtil.load(plugin, "guis.yml"); warnings.clear(); }
    public FileConfiguration raw() { return config; }
    public String title(String gui, String def) { return config.getString("guis." + gui + ".title", def); }
    public int size(String gui, int def) { int size = config.getInt("guis." + gui + ".size", def); return size % 9 == 0 && size >= 9 && size <= 54 ? size : def; }
    public List<Integer> intList(String path) { return config.getIntegerList(path); }

    public Material material(String raw, Material fallback, String context) {
        if (raw != null && raw.startsWith("%") && raw.endsWith("%")) return fallback;
        Material material = Material.matchMaterial(raw == null ? fallback.name() : raw);
        if (material == null) {
            warn("Invalid GUI material '" + raw + "' at " + context + "; using BARRIER.");
            return Material.BARRIER;
        }
        return material;
    }

    public Map<String, GuiItemConfig> items(String gui) {
        Map<String, GuiItemConfig> items = new LinkedHashMap<>();
        ConfigurationSection section = config.getConfigurationSection("guis." + gui + ".items");
        if (section == null) return items;
        for (String id : section.getKeys(false)) {
            ConfigurationSection item = section.getConfigurationSection(id);
            if (item != null) items.put(id, GuiItemConfig.from(id, item, Material.STONE));
        }
        return items;
    }

    public void warn(String message) {
        if (warnings.add(message)) plugin.getLogger().warning(message);
    }
}
