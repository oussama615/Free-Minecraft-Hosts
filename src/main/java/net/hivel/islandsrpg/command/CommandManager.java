package net.hivel.islandsrpg.command;
import net.hivel.islandsrpg.IslandsRPGPlugin;
public class CommandManager { public CommandManager(IslandsRPGPlugin p){var cmd=p.getCommand("islands"); IslandsCommand ic=new IslandsCommand(p); if(cmd!=null){cmd.setExecutor(ic); cmd.setTabCompleter(ic);}} }
