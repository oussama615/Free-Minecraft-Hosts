package com.strawio.voicechat.di

import com.strawio.voicechat.data.*
import com.strawio.voicechat.domain.*
import com.strawio.voicechat.security.AndroidKeystoreDeviceIdentityManager
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class AppModule {
    @Binds @Singleton abstract fun bindMinecraftDetectionService(impl: LocalMinecraftDetectionService): MinecraftDetectionService
    @Binds abstract fun bindVoiceBackendClient(impl: NoOpVoiceBackendClient): VoiceBackendClient
    @Binds abstract fun bindVoiceSessionManager(impl: NoOpVoiceSessionManager): VoiceSessionManager
    @Binds @Singleton abstract fun bindDeviceIdentityManager(impl: AndroidKeystoreDeviceIdentityManager): DeviceIdentityManager
    @Binds abstract fun bindMicrophoneService(impl: NoOpMicrophoneService): MicrophoneService
    @Binds abstract fun bindPluginHandshakeManager(impl: NoOpPluginHandshakeManager): PluginHandshakeManager
    @Binds abstract fun bindIntegrityVerifier(impl: LocalIntegrityVerifier): IntegrityVerifier
}
