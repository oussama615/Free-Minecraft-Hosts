package net.hivel.islandsrpg.level;
import org.bukkit.configuration.file.FileConfiguration;
public class XpFormula { private final FileConfiguration c; public XpFormula(FileConfiguration c){this.c=c;} public long requiredXp(int level){double base=c.getDouble("leveling.base-xp",100), linear=c.getDouble("leveling.linear-xp",35), curve=c.getDouble("leveling.curve-xp",0.12); return Math.max(1, Math.round(base + level*linear + level*level*curve));} public int maxLevel(){return c.getInt("leveling.max-level",1000);} }
