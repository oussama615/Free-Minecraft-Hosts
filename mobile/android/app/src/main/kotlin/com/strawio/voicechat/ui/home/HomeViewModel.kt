package com.strawio.voicechat.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.strawio.voicechat.BuildConfig
import com.strawio.voicechat.data.LocalMinecraftDetectionService
import com.strawio.voicechat.domain.*
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.time.Instant
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val detectionService: MinecraftDetectionService,
    private val deviceIdentityManager: DeviceIdentityManager,
) : ViewModel() {
    private val privacyVisible = MutableStateFlow(false)

    val uiState: StateFlow<HomeUiState> = combine(detectionService.state, privacyVisible) { state, about ->
        HomeUiState(
            connection = StateFormatting.toUiModel(state),
            rawState = state,
            showPrivacy = about,
            debugToolsEnabled = BuildConfig.DEBUG_TOOLS_ENABLED,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), HomeUiState.default())

    init {
        viewModelScope.launch {
            runCatching { deviceIdentityManager.ensureDeviceIdentity() }
            detectionService.refreshOnce()
        }
    }

    fun showPrivacy() { privacyVisible.value = true }
    fun hidePrivacy() { privacyVisible.value = false }

    fun simulateDebugState(kind: DebugSimulation) {
        if (!BuildConfig.DEBUG_TOOLS_ENABLED) return
        val local = detectionService as? LocalMinecraftDetectionService ?: return
        local.debugSetState(when (kind) {
            DebugSimulation.Waiting -> VoiceChatState.WaitingForMinecraft
            DebugSimulation.MinecraftDetected -> VoiceChatState.MinecraftDetected("Preview player")
            DebugSimulation.SupportedServer -> VoiceChatState.WaitingForSupportedServer("Preview player")
            DebugSimulation.Connected -> StateFormatting.previewConnectedState().copy(connectionTimestamp = Instant.now())
            DebugSimulation.Disconnected -> VoiceChatState.Disconnected()
            DebugSimulation.Error -> VoiceChatState.Error(SafeError.Unexpected)
        })
    }
}

data class HomeUiState(
    val connection: ConnectionUiModel,
    val rawState: VoiceChatState,
    val showPrivacy: Boolean,
    val debugToolsEnabled: Boolean,
) {
    companion object {
        fun default() = HomeUiState(StateFormatting.toUiModel(StateFormatting.productionDefault()), StateFormatting.productionDefault(), false, false)
    }
}

enum class DebugSimulation { Waiting, MinecraftDetected, SupportedServer, Connected, Disconnected, Error }
