package net.hivel.islandsrpg.util;
import org.bukkit.configuration.file.*; import org.bukkit.plugin.java.JavaPlugin; import java.io.File;
public final class ConfigUtil { private ConfigUtil(){} public static FileConfiguration load(JavaPlugin p,String name){ p.saveResource(name,false); return YamlConfiguration.loadConfiguration(new File(p.getDataFolder(),name)); } }
