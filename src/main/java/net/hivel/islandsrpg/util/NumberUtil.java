package net.hivel.islandsrpg.util;
import java.text.DecimalFormat;
import java.util.concurrent.ThreadLocalRandom;
public final class NumberUtil { private static final DecimalFormat F = new DecimalFormat("#,###"); private NumberUtil(){} public static String format(long n){return F.format(n);} public static int rand(int min,int max){return max<=min?min:ThreadLocalRandom.current().nextInt(min,max+1);} public static double clamp(double v,double min,double max){return Math.max(min, Math.min(max, v));} }
