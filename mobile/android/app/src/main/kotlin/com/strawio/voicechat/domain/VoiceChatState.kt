package com.strawio.voicechat.domain

import java.time.Instant

data class PlayerIdentity(
    val displayName: String,
    val uuid: String? = null,
)

data class ServerIdentity(
    val name: String,
    val serverId: String? = null,
)

sealed interface VoiceChatState {
    data object Initializing : VoiceChatState
    data object WaitingForMinecraft : VoiceChatState
    data class MinecraftDetected(val playerNameHint: String? = null) : VoiceChatState
    data class WaitingForSupportedServer(val playerNameHint: String? = null) : VoiceChatState
    data class Connecting(val serverName: String? = null) : VoiceChatState
    data class Connected(
        val playerName: String,
        val playerUuid: String?,
        val serverName: String,
        val serverId: String?,
        val connectionTimestamp: Instant,
        val appVersion: String,
        val protocolVersion: String,
    ) : VoiceChatState
    data class Disconnected(val reason: SafeError = SafeError.ConnectionUnavailable) : VoiceChatState
    data object UnsupportedServer : VoiceChatState
    data object PermissionRequired : VoiceChatState
    data object UpdateRequired : VoiceChatState
    data class Error(val error: SafeError) : VoiceChatState
}

enum class SafeError(val userMessage: String) {
    MinecraftNotRunning("Minecraft is not running."),
    NoSupportedServer("No supported server detected."),
    ConnectionUnavailable("Connection unavailable."),
    AppOutdated("App version is outdated."),
    DeviceSecurityUnavailable("Device security is unavailable."),
    Unexpected("An unexpected error occurred.")
}
