package com.strawio.voicechat.domain

import com.strawio.voicechat.BuildConfig

object StateFormatting {
    fun toUiModel(state: VoiceChatState): ConnectionUiModel = when (state) {
        VoiceChatState.Initializing -> ConnectionUiModel("Initializing", "Player: Not detected", "Server: Waiting for Minecraft", "Status: Standby", StatusTone.Neutral)
        VoiceChatState.WaitingForMinecraft -> ConnectionUiModel("Waiting for Minecraft...", "Player: Not detected", "Server: Waiting for Minecraft", "Status: Standby", StatusTone.Neutral)
        is VoiceChatState.MinecraftDetected -> ConnectionUiModel("Minecraft detected", "Player: ${sanitize(state.playerNameHint ?: "Not detected")}", "Server: Waiting for supported server", "Status: Minecraft detected", StatusTone.Gold)
        is VoiceChatState.WaitingForSupportedServer -> ConnectionUiModel("Waiting for supported server", "Player: ${sanitize(state.playerNameHint ?: "Not detected")}", "Server: Waiting for supported server", "Status: Standby", StatusTone.Gold)
        is VoiceChatState.Connecting -> ConnectionUiModel("Connecting to supported server", "Player: Not detected", "Server: ${sanitize(state.serverName ?: "Supported server detected")}", "Status: Connecting", StatusTone.Gold)
        is VoiceChatState.Connected -> ConnectionUiModel("Auto-detecting supported Minecraft server", "Player: ${sanitize(state.playerName)}", "Server: ${sanitize(state.serverName)}", "Status: Connected Automatically", StatusTone.Active)
        is VoiceChatState.Disconnected -> ConnectionUiModel("Connection lost", "Player: Not detected", "Server: Waiting for Minecraft", "Status: ${state.reason.userMessage}", StatusTone.Warning)
        VoiceChatState.UnsupportedServer -> ConnectionUiModel("Unsupported server", "Player: Not detected", "Server: No supported server detected", "Status: Unsupported server", StatusTone.Warning)
        VoiceChatState.PermissionRequired -> ConnectionUiModel("Permission required", "Player: Not detected", "Server: Waiting for Minecraft", "Status: Permission required", StatusTone.Warning)
        VoiceChatState.UpdateRequired -> ConnectionUiModel("App update required", "Player: Not detected", "Server: Waiting for Minecraft", "Status: App version is outdated", StatusTone.Warning)
        is VoiceChatState.Error -> ConnectionUiModel("Connection unavailable", "Player: Not detected", "Server: Waiting for Minecraft", "Status: ${state.error.userMessage}", StatusTone.Error)
    }

    fun productionDefault(): VoiceChatState = VoiceChatState.WaitingForMinecraft

    fun previewConnectedState(): VoiceChatState.Connected = VoiceChatState.Connected(
        playerName = if (BuildConfig.DEBUG) "xk7" else "Not detected",
        playerUuid = null,
        serverName = if (BuildConfig.DEBUG) "Hivel Network" else "Waiting for Minecraft",
        serverId = null,
        connectionTimestamp = java.time.Instant.EPOCH,
        appVersion = BuildConfig.VERSION_NAME,
        protocolVersion = BuildConfig.PROTOCOL_VERSION,
    )

    fun sanitize(value: String): String = value
        .replace(Regex("<[^>]*>"), "")
        .replace(Regex("[\\r\\n\\t]"), " ")
        .take(80)
        .ifBlank { "Not detected" }
}

data class ConnectionUiModel(
    val title: String,
    val playerLine: String,
    val serverLine: String,
    val statusLine: String,
    val tone: StatusTone,
)

enum class StatusTone { Neutral, Gold, Active, Warning, Error }
