package com.strawio.voicechat.domain

import kotlinx.coroutines.flow.Flow

interface MinecraftDetectionService {
    val state: Flow<VoiceChatState>
    suspend fun refreshOnce()
}

interface VoiceBackendClient {
    suspend fun prepareHandshake(): Result<Unit>
}

interface VoiceSessionManager {
    val state: Flow<VoiceChatState>
    suspend fun stopSession()
}

interface DeviceIdentityManager {
    suspend fun ensureDeviceIdentity(): DeviceIdentity
    suspend fun signChallenge(challenge: ByteArray): ByteArray
}

data class DeviceIdentity(
    val publicKeyId: String,
    val algorithm: String,
    val hardwareBacked: Boolean,
)

interface MicrophoneService {
    val isPrepared: Boolean
    suspend fun prepareForFuturePermissionFlow()
}

interface PluginHandshakeManager {
    suspend fun validateHandshakeCapability(): Result<Unit>
}

interface IntegrityVerifier {
    suspend fun collectIntegritySignal(): IntegritySignal
}

data class IntegritySignal(
    val packageName: String,
    val signatureKnown: Boolean,
    val playIntegrityAvailable: Boolean,
)
