package net.hivel.islandsrpg.quest;
public record Quest(String id,String displayName,String island,QuestType type,String target,int amount,long xp,long money,long fragments,String next,boolean repeatable,boolean daily) {}
