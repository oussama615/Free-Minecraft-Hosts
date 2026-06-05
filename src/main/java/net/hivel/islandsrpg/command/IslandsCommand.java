package net.hivel.islandsrpg.command;

import net.hivel.islandsrpg.IslandsRPGPlugin;
import net.hivel.islandsrpg.util.ColorUtil;
import org.bukkit.Bukkit;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.command.TabCompleter;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;

import java.util.ArrayList;
import java.util.List;

public class IslandsCommand implements CommandExecutor, TabCompleter {
    private final IslandsRPGPlugin plugin;

    public IslandsCommand(IslandsRPGPlugin plugin) {
        this.plugin = plugin;
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        try {
            if (args.length == 0) {
                if (sender instanceof Player player) plugin.guis().openMain(player);
                else help(sender);
                return true;
            }
            String sub = args[0].toLowerCase();
            if (sender instanceof Player player) {
                switch (sub) {
                    case "stats" -> plugin.guis().openStats(player);
                    case "profile" -> plugin.guis().openProfile(player);
                    case "quests" -> plugin.guis().openQuests(player);
                    case "islands", "isles" -> plugin.guis().openIslands(player);
                    case "weapons" -> plugin.guis().openWeapons(player);
                    case "help" -> help(sender);
                    default -> {
                        if (!admin(sender)) return true;
                        admin(sender, sub, args);
                    }
                }
            } else {
                if (!admin(sender)) return true;
                admin(sender, sub, args);
            }
        } catch (Exception e) {
            sender.sendMessage(ColorUtil.color("&cᴇʀʀᴏʀ&7: " + e.getMessage()));
        }
        return true;
    }

    private boolean admin(CommandSender sender) {
        if (!sender.hasPermission("islands.admin")) {
            sender.sendMessage(ColorUtil.color("&cᴇʀʀᴏʀ&7: no permission."));
            return false;
        }
        return true;
    }

    private void admin(CommandSender sender, String sub, String[] args) {
        switch (sub) {
            case "reload" -> { plugin.reloadAll(); sender.sendMessage(ColorUtil.color(plugin.message("reloaded"))); }
            case "addxp" -> { Player target = player(sender, args, 1); if (target != null && num(args, 2)) plugin.levels().addXp(target, Long.parseLong(args[2])); }
            case "setlevel" -> { Player target = player(sender, args, 1); if (target != null && num(args, 2)) plugin.levels().setLevel(target, Integer.parseInt(args[2])); }
            case "money" -> { Player target = player(sender, args, 2); if (target != null && args.length > 3 && num(args, 3)) { if ("give".equalsIgnoreCase(args[1])) plugin.currency().addMoney(target, Long.parseLong(args[3])); else if ("set".equalsIgnoreCase(args[1])) plugin.currency().setMoney(target, Long.parseLong(args[3])); } }
            case "fragments" -> { Player target = player(sender, args, 2); if (target != null && args.length > 3 && num(args, 3)) { if ("give".equalsIgnoreCase(args[1])) plugin.currency().addFragments(target, Long.parseLong(args[3])); else if ("set".equalsIgnoreCase(args[1])) plugin.currency().setFragments(target, Long.parseLong(args[3])); } }
            case "points" -> { Player target = player(sender, args, 2); if (target != null && args.length > 3 && "give".equalsIgnoreCase(args[1]) && num(args, 3)) { var data = plugin.data().get(target); data.statPoints += Integer.parseInt(args[3]); plugin.data().save(data); } }
            case "giveweapon" -> { Player target = player(sender, args, 1); if (target != null && args.length > 2) { ItemStack item = plugin.weapons().item(args[2]); if (item != null) target.getInventory().addItem(item); } }
            case "givemagic" -> { Player target = player(sender, args, 1); if (target != null && args.length > 2) { ItemStack item = plugin.magic().item(args[2]); if (item != null) target.getInventory().addItem(item); } }
            case "spawnmob" -> { if (sender instanceof Player player && args.length > 1) plugin.mobs().spawn(args[1], player.getLocation()); }
            case "spawnboss" -> { if (sender instanceof Player player && args.length > 1) plugin.bosses().spawn(args[1], player.getLocation()); }
            case "setislandspawn" -> { if (sender instanceof Player player && args.length > 1) plugin.islands().setSpawn(args[1], player.getLocation()); }
            case "startquest" -> { Player target = player(sender, args, 1); if (target != null && args.length > 2) plugin.quests().start(target, args[2]); }
            case "completequest" -> { Player target = player(sender, args, 1); if (target != null && args.length > 2) plugin.quests().complete(target, args[2]); }
            default -> help(sender);
        }
    }

    private Player player(CommandSender sender, String[] args, int index) {
        if (args.length <= index) {
            sender.sendMessage(ColorUtil.color("&cᴇʀʀᴏʀ&7: missing player."));
            return null;
        }
        Player player = Bukkit.getPlayerExact(args[index]);
        if (player == null) sender.sendMessage(ColorUtil.color("&cᴇʀʀᴏʀ&7: player not found."));
        return player;
    }

    private boolean num(String[] args, int index) {
        if (args.length <= index) return false;
        try { Long.parseLong(args[index]); return true; } catch (Exception e) { return false; }
    }

    private void help(CommandSender sender) {
        sender.sendMessage(ColorUtil.color("&bɪꜱʟᴀɴᴅꜱ&8 » &f/islands &7- open main menu"));
        sender.sendMessage(ColorUtil.color("&bɪꜱʟᴀɴᴅꜱ&8 » &f/stats &7- open stats"));
        sender.sendMessage(ColorUtil.color("&bɪꜱʟᴀɴᴅꜱ&8 » &f/quests &7- open quests"));
        sender.sendMessage(ColorUtil.color("&bɪꜱʟᴀɴᴅꜱ&8 » &f/profile &7- view profile"));
        sender.sendMessage(ColorUtil.color("&bɪꜱʟᴀɴᴅꜱ&8 » &f/weapons &7- view weapons"));
        sender.sendMessage(ColorUtil.color("&bɪꜱʟᴀɴᴅꜱ&8 » &f/isles &7- travel between islands"));
        if (sender.hasPermission("islands.admin")) {
            sender.sendMessage(ColorUtil.color("&8&m----------------"));
            sender.sendMessage(ColorUtil.color("&cᴀᴅᴍɪɴ&8 » &7/islands reload"));
            sender.sendMessage(ColorUtil.color("&cᴀᴅᴍɪɴ&8 » &7/islands addxp <player> <amount>"));
            sender.sendMessage(ColorUtil.color("&cᴀᴅᴍɪɴ&8 » &7/islands setlevel <player> <level>"));
            sender.sendMessage(ColorUtil.color("&cᴀᴅᴍɪɴ&8 » &7/islands money give|set <player> <amount>"));
            sender.sendMessage(ColorUtil.color("&cᴀᴅᴍɪɴ&8 » &7/islands fragments give|set <player> <amount>"));
            sender.sendMessage(ColorUtil.color("&cᴀᴅᴍɪɴ&8 » &7/islands points give <player> <amount>"));
            sender.sendMessage(ColorUtil.color("&cᴀᴅᴍɪɴ&8 » &7/islands giveweapon|givemagic <player> <id>"));
            sender.sendMessage(ColorUtil.color("&cᴀᴅᴍɪɴ&8 » &7/islands spawnmob|spawnboss <id>"));
            sender.sendMessage(ColorUtil.color("&cᴀᴅᴍɪɴ&8 » &7/islands setislandspawn <islandId>"));
            sender.sendMessage(ColorUtil.color("&cᴀᴅᴍɪɴ&8 » &7/islands startquest|completequest <player> <questId>"));
        }
    }

    @Override
    public List<String> onTabComplete(CommandSender sender, Command command, String label, String[] args) {
        List<String> base = new ArrayList<>(List.of("stats", "profile", "quests", "islands", "isles", "weapons", "help"));
        if (sender.hasPermission("islands.admin")) base.addAll(List.of("reload", "addxp", "setlevel", "money", "fragments", "points", "giveweapon", "givemagic", "spawnmob", "spawnboss", "setislandspawn", "startquest", "completequest"));
        if (args.length == 1) return base.stream().filter(option -> option.startsWith(args[0].toLowerCase())).toList();
        if (args.length == 2 && List.of("addxp", "setlevel", "giveweapon", "givemagic", "startquest", "completequest").contains(args[0].toLowerCase())) return Bukkit.getOnlinePlayers().stream().map(Player::getName).toList();
        if (args.length == 3 && "giveweapon".equalsIgnoreCase(args[0])) return plugin.weapons().all().stream().map(weapon -> weapon.id()).toList();
        if (args.length == 3 && "givemagic".equalsIgnoreCase(args[0])) return plugin.magic().all().stream().map(magic -> magic.id()).toList();
        if (args.length == 2 && "spawnmob".equalsIgnoreCase(args[0])) return plugin.mobs().all().stream().map(mob -> mob.id()).toList();
        if (args.length == 2 && "spawnboss".equalsIgnoreCase(args[0])) return plugin.bosses().all().stream().map(boss -> boss.id()).toList();
        if (args.length == 2 && "setislandspawn".equalsIgnoreCase(args[0])) return plugin.islands().all().stream().map(island -> island.id()).toList();
        if (args.length == 3 && List.of("startquest", "completequest").contains(args[0].toLowerCase())) return plugin.quests().all().stream().map(quest -> quest.id()).toList();
        if (args.length == 2 && List.of("money", "fragments", "points").contains(args[0].toLowerCase())) return List.of("give", "set");
        if (args.length == 3 && List.of("money", "fragments", "points").contains(args[0].toLowerCase())) return Bukkit.getOnlinePlayers().stream().map(Player::getName).toList();
        return List.of();
    }
}
