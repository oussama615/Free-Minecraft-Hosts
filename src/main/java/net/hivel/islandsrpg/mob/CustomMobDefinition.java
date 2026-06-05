package net.hivel.islandsrpg.mob;
import net.hivel.islandsrpg.drop.DropDefinition; import org.bukkit.entity.EntityType; import java.util.*;
public record CustomMobDefinition(String id, EntityType entity, String displayName, String island, int level, double health, double damage, long xp, long money, long fragments, boolean showHealthName, boolean bossbar, boolean glowing, boolean baby, boolean silent, boolean spawningEnabled, int maxAlive, int intervalSeconds, int amount, double radius, List<String> locations, Map<String,DropDefinition> drops) {}
