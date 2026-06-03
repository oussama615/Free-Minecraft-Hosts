package com.empcontrol.agent.config;
public record AgentIdentity(String serverId, String agentSecret, String apiBaseUrl, String websocketPath, String publicIdentity) {}
