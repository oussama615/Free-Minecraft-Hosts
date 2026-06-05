package net.hivel.islandsrpg.placeholder;

import net.hivel.islandsrpg.IslandsRPGPlugin;
import net.hivel.islandsrpg.data.PlayerData;
import net.hivel.islandsrpg.island.Island;
import net.hivel.islandsrpg.magic.MagicItemDefinition;
import net.hivel.islandsrpg.quest.Quest;
import net.hivel.islandsrpg.quest.QuestProgress;
import net.hivel.islandsrpg.stats.StatType;
import net.hivel.islandsrpg.util.NumberUtil;
import net.hivel.islandsrpg.weapon.WeaponDefinition;
import org.bukkit.entity.Player;

import java.util.List;

public class PlaceholderService {
    private final IslandsRPGPlugin plugin;

    public PlaceholderService(IslandsRPGPlugin plugin) {
        this.plugin = plugin;
    }

    public String apply(Player player, String text) {
        return apply(player, text, null, null, null, null, null, null);
    }

    public List<String> apply(Player player, List<String> lines) {
        return lines.stream().map(line -> apply(player, line)).toList();
    }

    public String apply(Player player, String text, Island island, Quest quest, QuestProgress progress, String questStatus, WeaponDefinition weapon, MagicItemDefinition magic) {
        if (text == null) return "";
        PlayerData data = plugin.data().get(player);
        String out = text
            .replace("%player%", player.getName())
            .replace("%uuid%", player.getUniqueId().toString())
            .replace("%level%", String.valueOf(data.level))
            .replace("%xp%", NumberUtil.format(data.xp))
            .replace("%required_xp%", NumberUtil.format(plugin.levels().requiredXp(data.level)))
            .replace("%money%", NumberUtil.format(data.money))
            .replace("%fragments%", NumberUtil.format(data.fragments))
            .replace("%stat_points%", String.valueOf(data.statPoints))
            .replace("%stat_melee%", String.valueOf(data.stat(StatType.MELEE)))
            .replace("%stat_defence%", String.valueOf(data.stat(StatType.DEFENCE)))
            .replace("%stat_sword%", String.valueOf(data.stat(StatType.SWORD)))
            .replace("%stat_magic%", String.valueOf(data.stat(StatType.MAGIC)))
            .replace("%stat_luck%", String.valueOf(data.stat(StatType.LUCK)));
        if (island != null) {
            out = out.replace("%island_id%", island.id())
                .replace("%island_name%", island.displayName())
                .replace("%required_level%", String.valueOf(island.requiredLevel()))
                .replace("%island_icon%", island.icon().name());
        }
        if (quest != null) {
            int current = progress == null ? 0 : progress.current();
            out = out.replace("%quest_id%", quest.id())
                .replace("%quest_name%", quest.displayName())
                .replace("%quest_target%", quest.target())
                .replace("%quest_progress%", String.valueOf(current))
                .replace("%quest_amount%", String.valueOf(quest.amount()))
                .replace("%quest_status%", questStatus == null ? "not_started" : questStatus)
                .replace("%quest_xp%", NumberUtil.format(quest.xp()))
                .replace("%quest_money%", NumberUtil.format(quest.money()))
                .replace("%quest_fragments%", NumberUtil.format(quest.fragments()))
                .replace("%quest_objective%", questObjective(player, quest, progress, questStatus));
        }
        if (weapon != null) {
            out = out.replace("%weapon_id%", weapon.id()).replace("%weapon_name%", weapon.displayName());
        }
        if (magic != null) {
            out = out.replace("%magic_id%", magic.id()).replace("%magic_name%", magic.displayName());
        }
        return plugin.theme().apply(out);
    }

    public String questObjective(Player player, Quest quest, QuestProgress progress, String status) {
        int current = progress == null ? 0 : progress.current();
        String format = plugin.scoreboardConfig().objectiveFormat(quest.type());
        String out = format
            .replace("%quest_id%", quest.id())
            .replace("%quest_name%", quest.displayName())
            .replace("%quest_target%", quest.target())
            .replace("%quest_progress%", String.valueOf(current))
            .replace("%quest_amount%", String.valueOf(quest.amount()))
            .replace("%quest_status%", status == null ? "not_started" : status)
            .replace("%quest_xp%", NumberUtil.format(quest.xp()))
            .replace("%quest_money%", NumberUtil.format(quest.money()))
            .replace("%quest_fragments%", NumberUtil.format(quest.fragments()));
        return plugin.theme().apply(out);
    }
}
