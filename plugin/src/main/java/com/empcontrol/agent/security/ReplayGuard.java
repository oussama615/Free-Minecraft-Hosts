package com.empcontrol.agent.security;
import java.util.*; public final class ReplayGuard { private final Set<String> seen = Collections.synchronizedSet(new LinkedHashSet<>()); public boolean accept(String nonce){ if(seen.contains(nonce)) return false; seen.add(nonce); if(seen.size()>500) seen.remove(seen.iterator().next()); return true; } }
