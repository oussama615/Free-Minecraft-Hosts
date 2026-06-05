package net.hivel.islandsrpg.gui;

import net.hivel.islandsrpg.IslandsRPGPlugin;
import net.hivel.islandsrpg.data.PlayerData;
import net.hivel.islandsrpg.island.Island;
import net.hivel.islandsrpg.magic.MagicItemDefinition;
import net.hivel.islandsrpg.quest.Quest;
import net.hivel.islandsrpg.quest.QuestProgress;
import net.hivel.islandsrpg.util.ItemBuilder;
import net.hivel.islandsrpg.weapon.WeaponDefinition;
import org.bukkit.Bukkit;
import org.bukkit.Material;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.entity.Player;
import org.bukkit.event.inventory.InventoryClickEvent;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.ItemStack;

import java.util.*;

public class GuiManager {
    private final IslandsRPGPlugin plugin;
    private final GuiConfig config;
    private final GuiActionExecutor executor;
    private final Map<UUID, Map<Integer, GuiAction>> actions = new HashMap<>();
    public final MainMenuGui main;
    public final StatsGui stats;
    public final IslandsGui islands;
    public final QuestsGui quests;
    public final ProfileGui profile;
    public final WeaponsGui weapons;

    public GuiManager(IslandsRPGPlugin plugin) {
        this.plugin = plugin;
        this.config = new GuiConfig(plugin);
        this.executor = new GuiActionExecutor(plugin);
        main = new MainMenuGui(plugin);
        stats = new StatsGui(plugin);
        islands = new IslandsGui(plugin);
        quests = new QuestsGui(plugin);
        profile = new ProfileGui(plugin);
        weapons = new WeaponsGui(plugin);
    }

    public void reload() { config.reload(); }
    public GuiConfig config() { return config; }
    public void openMain(Player player) { openStatic(player, "main", "&8ɪꜱʟᴀɴᴅꜱ ʀᴘɢ"); }
    public void openStats(Player player) { openStatic(player, "stats", "&8ꜱᴛᴀᴛꜱ"); }
    public void openProfile(Player player) { openStatic(player, "profile", "&8ᴘʀᴏꜰɪʟᴇ"); }

    public void openStatic(Player player, String id, String defaultTitle) {
        Inventory inv = base(player, id, defaultTitle);
        Map<Integer, GuiAction> map = new HashMap<>();
        for (GuiItemConfig item : config.items(id).values()) set(player, inv, map, item, null, null, null, null, null);
        open(player, inv, map);
    }

    public void openIslands(Player player) {
        Inventory inv = base(player, "islands", "&8ɪꜱʟᴀɴᴅꜱ");
        Map<Integer, GuiAction> map = new HashMap<>();
        List<Integer> slots = config.intList("guis.islands.island-slots");
        int i = 0;
        PlayerData data = plugin.data().get(player);
        for (Island island : plugin.islands().all()) {
            if (i >= slots.size()) break;
            boolean unlocked = plugin.islands().canUse(data, island);
            ConfigurationSection template = config.raw().getConfigurationSection("guis.islands." + (unlocked ? "unlocked" : "locked"));
            if (template != null) setIsland(player, inv, map, slots.get(i), template, island, unlocked);
            i++;
        }
        for (GuiItemConfig item : config.items("islands").values()) set(player, inv, map, item, null, null, null, null, null);
        open(player, inv, map);
    }

    public void openQuests(Player player) {
        Inventory inv = base(player, "quests", "&8ǫᴜᴇꜱᴛꜱ");
        Map<Integer, GuiAction> map = new HashMap<>();
        List<Integer> slots = config.intList("guis.quests.quest-slots");
        PlayerData data = plugin.data().get(player);
        int i = 0;
        for (Quest quest : plugin.quests().all()) {
            if (i >= slots.size()) break;
            QuestProgress progress = data.activeQuests.get(quest.id());
            String status = progress != null ? "active" : data.completedQuests.contains(quest.id()) ? "completed" : "not_started";
            ConfigurationSection template = config.raw().getConfigurationSection("guis.quests.statuses." + status);
            if (template != null) setQuest(player, inv, map, slots.get(i), template, quest, progress, status);
            i++;
        }
        for (GuiItemConfig item : config.items("quests").values()) set(player, inv, map, item, null, null, null, null, null);
        open(player, inv, map);
    }

    public void openWeapons(Player player) {
        Inventory inv = base(player, "weapons", "&8ᴡᴇᴀᴘᴏɴꜱ");
        Map<Integer, GuiAction> map = new HashMap<>();
        List<Integer> slots = config.intList("guis.weapons.weapon-slots");
        int i = 0;
        for (WeaponDefinition weapon : plugin.weapons().all()) {
            if (i >= slots.size()) break;
            ItemStack item = plugin.weapons().item(weapon.id());
            inv.setItem(slots.get(i), item);
            map.put(slots.get(i), new GuiAction(GuiAction.Type.WEAPON_PREVIEW, weapon.id(), ""));
            i++;
        }
        for (MagicItemDefinition magic : plugin.magic().all()) {
            if (i >= slots.size()) break;
            inv.setItem(slots.get(i), plugin.magic().item(magic.id()));
            map.put(slots.get(i), new GuiAction(GuiAction.Type.NONE, magic.id(), ""));
            i++;
        }
        for (GuiItemConfig item : config.items("weapons").values()) set(player, inv, map, item, null, null, null, null, null);
        open(player, inv, map);
    }

    public void handle(InventoryClickEvent event) {
        if (!(event.getWhoClicked() instanceof Player player)) return;
        Map<Integer, GuiAction> map = actions.get(player.getUniqueId());
        if (map == null) return;
        event.setCancelled(true);
        GuiAction action = map.get(event.getSlot());
        if (action != null) executor.execute(player, action);
    }

    private Inventory base(Player player, String gui, String defaultTitle) {
        int size = config.size(gui, 54);
        Inventory inv = Bukkit.createInventory(null, size, plugin.placeholders().apply(player, config.title(gui, defaultTitle)));
        ConfigurationSection filler = config.raw().getConfigurationSection("guis." + gui + ".filler");
        if (filler != null && filler.getBoolean("enabled", false)) {
            Material material = config.material(filler.getString("material", "BLACK_STAINED_GLASS_PANE"), Material.BLACK_STAINED_GLASS_PANE, gui + ".filler");
            ItemStack item = new ItemBuilder(material).name(plugin.theme().apply(filler.getString("name", "&8"))).build();
            List<Integer> slots = filler.getIntegerList("slots");
            if (slots.isEmpty()) for (int i = 0; i < size; i++) inv.setItem(i, item);
            else for (int slot : slots) if (slot >= 0 && slot < size) inv.setItem(slot, item); else config.warn("GUI filler slot outside inventory: " + gui + " " + slot);
        }
        return inv;
    }

    private void set(Player player, Inventory inv, Map<Integer, GuiAction> map, GuiItemConfig item, Island island, Quest quest, QuestProgress progress, String status, WeaponDefinition weapon) {
        if (item.slot() < 0 || item.slot() >= inv.getSize()) { config.warn("GUI slot outside inventory: " + item.id() + " " + item.slot()); return; }
        List<String> lore = item.lore().stream().map(line -> plugin.placeholders().apply(player, line, island, quest, progress, status, weapon, null)).toList();
        ItemStack stack = new ItemBuilder(item.material()).name(plugin.placeholders().apply(player, item.name(), island, quest, progress, status, weapon, null)).lore(lore).glow(item.glow()).customModelData(item.customModelData()).build();
        inv.setItem(item.slot(), stack);
        map.put(item.slot(), item.action());
    }

    private void setIsland(Player player, Inventory inv, Map<Integer, GuiAction> map, int slot, ConfigurationSection template, Island island, boolean unlocked) {
        if (slot < 0 || slot >= inv.getSize()) { config.warn("Island GUI slot outside inventory: " + slot); return; }
        String matRaw = plugin.placeholders().apply(player, template.getString("material", unlocked ? "%island_icon%" : "GRAY_DYE"), island, null, null, null, null, null);
        Material material = config.material(matRaw, island.icon(), "islands." + island.id());
        List<String> lore = template.getStringList("lore").stream().map(line -> plugin.placeholders().apply(player, line, island, null, null, null, null, null)).toList();
        inv.setItem(slot, new ItemBuilder(material).name(plugin.placeholders().apply(player, template.getString("name", "%island_name%"), island, null, null, null, null, null)).lore(lore).glow(template.getBoolean("glow", false)).build());
        map.put(slot, GuiAction.parse(plugin.placeholders().apply(player, template.getString("action", unlocked ? "ISLAND_TELEPORT:%island_id%" : "NONE"), island, null, null, null, null, null)));
    }

    private void setQuest(Player player, Inventory inv, Map<Integer, GuiAction> map, int slot, ConfigurationSection template, Quest quest, QuestProgress progress, String status) {
        if (slot < 0 || slot >= inv.getSize()) { config.warn("Quest GUI slot outside inventory: " + slot); return; }
        Material material = config.material(template.getString("material", "BOOK"), Material.BOOK, "quests." + quest.id());
        List<String> lore = template.getStringList("lore").stream().map(line -> plugin.placeholders().apply(player, line, null, quest, progress, status, null, null)).toList();
        inv.setItem(slot, new ItemBuilder(material).name(plugin.placeholders().apply(player, template.getString("name", "%quest_name%"), null, quest, progress, status, null, null)).lore(lore).glow(template.getBoolean("glow", false)).build());
        map.put(slot, GuiAction.parse(plugin.placeholders().apply(player, template.getString("action", "NONE"), null, quest, progress, status, null, null)));
    }

    private void open(Player player, Inventory inv, Map<Integer, GuiAction> map) {
        actions.put(player.getUniqueId(), map);
        player.openInventory(inv);
    }
}
