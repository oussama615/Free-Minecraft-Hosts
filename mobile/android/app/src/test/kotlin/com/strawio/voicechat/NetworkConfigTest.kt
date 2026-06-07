package com.strawio.voicechat

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import java.io.File

class NetworkConfigTest {
    @Test fun manifestDisablesCleartextTraffic() {
        val manifest = File("src/main/AndroidManifest.xml").readText()
        assertThat(manifest).contains("android:usesCleartextTraffic=\"false\"")
        assertThat(manifest).contains("android:allowBackup=\"false\"")
    }

    @Test fun noMicrophonePermissionDeclaredInPhaseOne() {
        val manifest = File("src/main/AndroidManifest.xml").readText()
        assertThat(manifest).doesNotContain("RECORD_AUDIO")
    }
}
