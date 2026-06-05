package net.hivel.islandsrpg.gui;

public record GuiAction(Type type, String first, String second) {
    public enum Type { OPEN_MAIN, OPEN_STATS, OPEN_ISLANDS, OPEN_QUESTS, OPEN_PROFILE, OPEN_WEAPONS, CLOSE, BACK, STAT_ADD, STAT_INFO, ISLAND_TELEPORT, QUEST_START, QUEST_CANCEL, WEAPON_PREVIEW, COMMAND, PLAYER_COMMAND, CONSOLE_COMMAND, NONE }

    public static GuiAction none() { return new GuiAction(Type.NONE, "", ""); }

    public static GuiAction parse(String raw) {
        if (raw == null || raw.isBlank()) return none();
        String[] parts = raw.split(":", 3);
        try {
            Type type = Type.valueOf(parts[0].trim().toUpperCase());
            return switch (type) {
                case STAT_ADD -> new GuiAction(type, parts.length > 1 ? parts[1] : "", parts.length > 2 ? parts[2] : "1");
                case STAT_INFO, ISLAND_TELEPORT, QUEST_START, QUEST_CANCEL, WEAPON_PREVIEW, COMMAND, PLAYER_COMMAND, CONSOLE_COMMAND -> new GuiAction(type, parts.length > 1 ? parts[1] : "", parts.length > 2 ? parts[2] : "");
                default -> new GuiAction(type, "", "");
            };
        } catch (Exception e) {
            return none();
        }
    }
}
