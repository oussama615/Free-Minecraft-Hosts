package net.hivel.islandsrpg.quest;
public class QuestProgress { private final String questId; private int current; public QuestProgress(String questId,int current){this.questId=questId;this.current=current;} public String questId(){return questId;} public int current(){return current;} public void add(int a){current+=a;} public void setCurrent(int c){current=c;} }
