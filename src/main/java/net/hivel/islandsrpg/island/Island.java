package net.hivel.islandsrpg.island;
import org.bukkit.Location; import org.bukkit.Material;
public record Island(String id, String displayName, int requiredLevel, Material icon, Location spawn) {}
