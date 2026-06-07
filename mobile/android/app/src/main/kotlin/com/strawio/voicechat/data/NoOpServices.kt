package com.strawio.voicechat.data

import com.strawio.voicechat.domain.*
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class NoOpVoiceBackendClient @Inject constructor() : VoiceBackendClient {
    override suspend fun prepareHandshake(): Result<Unit> = Result.success(Unit)
}

class NoOpVoiceSessionManager @Inject constructor(
    detectionService: MinecraftDetectionService,
) : VoiceSessionManager {
    override val state: Flow<VoiceChatState> = detectionService.state
    override suspend fun stopSession() = Unit
}

class NoOpMicrophoneService @Inject constructor() : MicrophoneService {
    override val isPrepared: Boolean = false
    override suspend fun prepareForFuturePermissionFlow() = Unit
}

class NoOpPluginHandshakeManager @Inject constructor() : PluginHandshakeManager {
    override suspend fun validateHandshakeCapability(): Result<Unit> = Result.success(Unit)
}

class LocalIntegrityVerifier @Inject constructor() : IntegrityVerifier {
    override suspend fun collectIntegritySignal(): IntegritySignal = IntegritySignal(
        packageName = "com.strawio.voicechat",
        signatureKnown = false,
        playIntegrityAvailable = false,
    )
}
