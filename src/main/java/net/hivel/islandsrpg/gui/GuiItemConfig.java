package net.hivel.islandsrpg.gui;

import org.bukkit.Material;
import org.bukkit.configuration.ConfigurationSection;

import java.util.List;

public record GuiItemConfig(String id, int slot, Material material, String name, List<String> lore, boolean glow, Integer customModelData, GuiAction action, GuiAction left, GuiAction shiftLeft, GuiAction right) {
    public static GuiItemConfig from(String id, ConfigurationSection section, Material fallback) {
        String materialName = section.getString("material", fallback.name());
        Material material = Material.matchMaterial(materialName == null ? fallback.name() : materialName);
        if (material == null) material = fallback;
        GuiAction action = GuiAction.parse(section.getString("action", "NONE"));
        ConfigurationSection actions = section.getConfigurationSection("actions");
        GuiAction left = actions == null ? action : GuiAction.parse(actions.getString("left", section.getString("action", "NONE")));
        GuiAction shiftLeft = actions == null ? action : GuiAction.parse(actions.getString("shift_left", section.getString("action", "NONE")));
        GuiAction right = actions == null ? action : GuiAction.parse(actions.getString("right", section.getString("action", "NONE")));
        Integer customModelData = section.contains("custom-model-data") ? section.getInt("custom-model-data") : null;
        return new GuiItemConfig(id, section.getInt("slot", 0), material, section.getString("name", id), section.getStringList("lore"), section.getBoolean("glow", false), customModelData, action, left, shiftLeft, right);
    }

    public GuiAction actionFor(org.bukkit.event.inventory.ClickType click) {
        if (click == org.bukkit.event.inventory.ClickType.RIGHT) return right;
        if (click == org.bukkit.event.inventory.ClickType.SHIFT_LEFT) return shiftLeft;
        return left;
    }
}
