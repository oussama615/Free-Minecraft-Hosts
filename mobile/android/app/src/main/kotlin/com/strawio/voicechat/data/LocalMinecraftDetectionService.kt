package com.strawio.voicechat.data

import com.strawio.voicechat.domain.MinecraftDetectionService
import com.strawio.voicechat.domain.StateFormatting
import com.strawio.voicechat.domain.VoiceChatState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LocalMinecraftDetectionService @Inject constructor() : MinecraftDetectionService {
    private val _state = MutableStateFlow(StateFormatting.productionDefault())
    override val state: StateFlow<VoiceChatState> = _state

    override suspend fun refreshOnce() {
        _state.value = VoiceChatState.WaitingForMinecraft
    }

    fun debugSetState(state: VoiceChatState) {
        _state.value = state
    }
}
