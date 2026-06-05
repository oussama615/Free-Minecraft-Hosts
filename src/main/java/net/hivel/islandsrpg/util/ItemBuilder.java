package net.hivel.islandsrpg.util;

import org.bukkit.*;
import org.bukkit.enchantments.Enchantment;
import org.bukkit.inventory.*;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.persistence.*;
import org.bukkit.plugin.java.JavaPlugin;

import java.util.*;

public class ItemBuilder {
    private final ItemStack item;

    public ItemBuilder(Material material) {
        item = new ItemStack(material == null ? Material.STONE : material);
    }

    public ItemBuilder name(String name) {
        ItemMeta meta = item.getItemMeta();
        if (meta != null && name != null && !name.isEmpty()) {
            meta.setDisplayName(ColorUtil.color(name));
            item.setItemMeta(meta);
        }
        return this;
    }

    public ItemBuilder lore(List<String> lore) {
        ItemMeta meta = item.getItemMeta();
        if (meta != null && lore != null) {
            meta.setLore(ColorUtil.color(lore));
            item.setItemMeta(meta);
        }
        return this;
    }

    public ItemBuilder glow(boolean glow) {
        if (glow) {
            ItemMeta meta = item.getItemMeta();
            if (meta != null) {
                meta.addEnchant(Enchantment.UNBREAKING, 1, true);
                meta.addItemFlags(ItemFlag.HIDE_ENCHANTS);
                item.setItemMeta(meta);
            }
        }
        return this;
    }

    public ItemBuilder customModelData(Integer customModelData) {
        if (customModelData != null) {
            ItemMeta meta = item.getItemMeta();
            if (meta != null) {
                meta.setCustomModelData(customModelData);
                item.setItemMeta(meta);
            }
        }
        return this;
    }

    public ItemBuilder unbreakable(boolean unbreakable) {
        ItemMeta meta = item.getItemMeta();
        if (meta != null) {
            meta.setUnbreakable(unbreakable);
            meta.addItemFlags(ItemFlag.HIDE_UNBREAKABLE);
            item.setItemMeta(meta);
        }
        return this;
    }

    public ItemBuilder pdc(JavaPlugin plugin, String key, String value) {
        ItemMeta meta = item.getItemMeta();
        if (meta != null) {
            meta.getPersistentDataContainer().set(new NamespacedKey(plugin, key), PersistentDataType.STRING, value);
            item.setItemMeta(meta);
        }
        return this;
    }

    public ItemStack build() {
        return item;
    }
}
