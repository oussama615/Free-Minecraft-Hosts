package net.hivel.islandsrpg.util;

import org.bukkit.ChatColor;
import java.util.List;

public final class ColorUtil {
    private ColorUtil() {}
    public static String color(String text) { return ChatColor.translateAlternateColorCodes('&', text == null ? "" : text); }
    public static List<String> color(List<String> lines) { return lines.stream().map(ColorUtil::color).toList(); }
    public static String stripEmojis(String s) { return s == null ? "" : s.replaceAll("[⭐✦◆⚔🌍📜🗡❤▪]", "").replaceAll("\\s+", " ").trim(); }
}
