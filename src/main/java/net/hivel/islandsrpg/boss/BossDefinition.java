package net.hivel.islandsrpg.boss;
import net.hivel.islandsrpg.drop.DropDefinition; import org.bukkit.boss.*; import org.bukkit.entity.EntityType; import java.util.*;
public record BossDefinition(String id, EntityType entity, String displayName, String island, int level, double health, double damage, long xp, long money, long fragments, boolean showHealthName, boolean bossbarEnabled, BarColor barColor, BarStyle barStyle, String barTitle, double barRange, Map<String,DropDefinition> drops) {}
