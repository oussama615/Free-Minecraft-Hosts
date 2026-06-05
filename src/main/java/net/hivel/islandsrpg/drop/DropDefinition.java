package net.hivel.islandsrpg.drop;
import java.util.*; import org.bukkit.Material;
public record DropDefinition(String id, DropType type, Material material, String displayName, double chance, int min, int max, String weaponId, String magicItemId, List<String> commands) {}
