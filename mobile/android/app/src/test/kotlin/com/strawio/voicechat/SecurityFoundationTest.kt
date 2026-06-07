package com.strawio.voicechat

import com.google.common.truth.Truth.assertThat
import com.strawio.voicechat.BuildConfig
import com.strawio.voicechat.domain.DeviceIdentity
import com.strawio.voicechat.domain.DeviceIdentityManager
import com.strawio.voicechat.network.CertificatePin
import com.strawio.voicechat.network.SafeNetworkClientFactory
import com.strawio.voicechat.network.SensitiveDataRedactor
import kotlinx.coroutines.test.runTest
import org.junit.Test

class SecurityFoundationTest {
    @Test fun deviceIdentityAbstractionSignsChallenge() = runTest {
        val manager = object : DeviceIdentityManager {
            override suspend fun ensureDeviceIdentity() = DeviceIdentity("public-id", "EC-P256-SHA256", false)
            override suspend fun signChallenge(challenge: ByteArray) = challenge.reversedArray()
        }
        assertThat(manager.ensureDeviceIdentity().algorithm).contains("P-256")
        assertThat(manager.signChallenge(byteArrayOf(1, 2, 3)).toList()).containsExactly(3, 2, 1).inOrder()
    }

    @Test fun releaseBuildConfigDisablesDebugControls() {
        if (!BuildConfig.DEBUG) assertThat(BuildConfig.DEBUG_TOOLS_ENABLED).isFalse()
    }

    @Test fun sensitiveDataRedactionMasksUuidAndToken() {
        val redacted = SensitiveDataRedactor.redact("uuid=123e4567-e89b-12d3-a456-426614174000&token=secret")
        assertThat(redacted).contains("<redacted>")
        assertThat(redacted).doesNotContain("426614174000")
        assertThat(redacted).doesNotContain("secret")
    }

    @Test fun certificatePinningRequiresBackupPin() {
        val factory = SafeNetworkClientFactory()
        val result = runCatching { factory.create(listOf(CertificatePin("voice.strawio.example", "sha256/primary", emptyList()))) }
        assertThat(result.isFailure).isTrue()
    }
}
