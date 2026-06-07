package com.strawio.voicechat

import com.google.common.truth.Truth.assertThat
import com.strawio.voicechat.domain.*
import org.junit.Test
import java.time.Instant

class StateFormattingTest {
    @Test fun defaultProductionStateIsWaitingForMinecraft() {
        assertThat(StateFormatting.productionDefault()).isEqualTo(VoiceChatState.WaitingForMinecraft)
        assertThat(StateFormatting.toUiModel(StateFormatting.productionDefault()).title).contains("Waiting for Minecraft")
    }

    @Test fun productionDefaultDoesNotContainHardcodedPlayerName() {
        val ui = StateFormatting.toUiModel(StateFormatting.productionDefault())
        assertThat(ui.playerLine).doesNotContain("xk7")
        assertThat(ui.serverLine).doesNotContain("Hivel Network")
    }

    @Test fun connectedStateMapsToAutomaticStatusWithoutUuid() {
        val ui = StateFormatting.toUiModel(VoiceChatState.Connected("Alex", "123e4567-e89b-12d3-a456-426614174000", "Supported Server", "server-one", Instant.EPOCH, "0.1", "v1"))
        assertThat(ui.playerLine).isEqualTo("Player: Alex")
        assertThat(ui.serverLine).isEqualTo("Server: Supported Server")
        assertThat(ui.statusLine).isEqualTo("Status: Connected Automatically")
        assertThat(ui.toString()).doesNotContain("123e4567")
    }

    @Test fun safeErrorMappingUsesUserMessagesOnly() {
        val ui = StateFormatting.toUiModel(VoiceChatState.Error(SafeError.DeviceSecurityUnavailable))
        assertThat(ui.statusLine).contains("Device security is unavailable")
        assertThat(ui.statusLine).doesNotContain("Exception")
    }

    @Test fun sanitizesServerControlledText() {
        assertThat(StateFormatting.sanitize("<b>Bad</b>\nServer")).isEqualTo("Bad Server")
    }
}
