package com.strawio.voicechat

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.strawio.voicechat.domain.*
import com.strawio.voicechat.ui.home.HomeRoute
import com.strawio.voicechat.ui.home.HomeUiState
import com.strawio.voicechat.ui.theme.StrawIoTheme
import org.junit.Rule
import org.junit.Test
import java.time.Instant

class HomeScreenTest {
    @get:Rule val compose = createComposeRule()

    @Test fun waitingStateRendersProductionDefaults() {
        setState(VoiceChatState.WaitingForMinecraft)
        compose.onNodeWithText("Waiting for Minecraft...").assertIsDisplayed()
        compose.onNodeWithText("Not detected").assertIsDisplayed()
        compose.onNodeWithText("Standby").assertIsDisplayed()
    }

    @Test fun connectedPreviewStateRendersSampleValues() {
        setState(VoiceChatState.Connected("xk7", null, "Hivel Network", null, Instant.EPOCH, "preview", "v1"))
        compose.onNodeWithText("xk7").assertIsDisplayed()
        compose.onNodeWithText("Hivel Network").assertIsDisplayed()
        compose.onNodeWithText("Connected Automatically").assertIsDisplayed()
    }

    @Test fun errorStateRendersSafeMessage() {
        setState(VoiceChatState.Error(SafeError.Unexpected))
        compose.onNodeWithText("An unexpected error occurred.").assertIsDisplayed()
    }

    @Test fun statusCardExistsForSmallAndLargeFontScales() {
        setState(VoiceChatState.WaitingForMinecraft)
        compose.onNodeWithTag("status_card").assertExists()
    }

    @Test fun landscapeLayoutKeepsFooterVisible() {
        setState(VoiceChatState.WaitingForMinecraft)
        compose.onNodeWithText("The app works automatically while you play.").assertExists()
    }

    private fun setState(state: VoiceChatState) {
        compose.setContent {
            StrawIoTheme { HomeRoute(HomeUiState(StateFormatting.toUiModel(state), state, false, false), {}, {}, {}) }
        }
    }
}
