package com.strawio.voicechat.security

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.strawio.voicechat.domain.DeviceIdentity
import com.strawio.voicechat.domain.DeviceIdentityManager
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import javax.inject.Inject
import javax.inject.Singleton

private val Context.identityDataStore by preferencesDataStore(name = "device_identity")

@Singleton
class AndroidKeystoreDeviceIdentityManager @Inject constructor(
    @ApplicationContext private val context: Context,
) : DeviceIdentityManager {
    private val alias = "strawio_voicechat_device_identity_p256"
    private val publicKeyIdPreference = stringPreferencesKey("public_key_id")

    override suspend fun ensureDeviceIdentity(): DeviceIdentity {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (!keyStore.containsAlias(alias)) generateKeyPair()
        val certificate = keyStore.getCertificate(alias)
        val publicKeyId = sha256Base64Url(certificate.publicKey.encoded)
        context.identityDataStore.edit { it[publicKeyIdPreference] = publicKeyId }
        return DeviceIdentity(publicKeyId = publicKeyId, algorithm = "EC-P256-SHA256", hardwareBacked = isHardwareBacked())
    }

    override suspend fun signChallenge(challenge: ByteArray): ByteArray {
        require(challenge.size in 16..4096) { "Invalid challenge size" }
        ensureDeviceIdentity()
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val privateKey = keyStore.getKey(alias, null) as PrivateKey
        return Signature.getInstance("SHA256withECDSA").run {
            initSign(privateKey)
            update(challenge)
            sign()
        }
    }

    suspend fun storedPublicKeyId(): String? = context.identityDataStore.data.first()[publicKeyIdPreference]

    private fun generateKeyPair() {
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
        val spec = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(false)
            .setIsStrongBoxBacked(false)
            .build()
        generator.initialize(spec)
        generator.generateKeyPair()
    }

    private fun isHardwareBacked(): Boolean = runCatching {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val privateKey = keyStore.getKey(alias, null) as PrivateKey
        val factory = KeyFactory.getInstance(privateKey.algorithm, "AndroidKeyStore")
        val info = factory.getKeySpec(privateKey, KeyInfo::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) info.securityLevel != KeyProperties.SECURITY_LEVEL_SOFTWARE else info.isInsideSecureHardware
    }.getOrDefault(false)

    private fun sha256Base64Url(bytes: ByteArray): String = android.util.Base64.encodeToString(
        MessageDigest.getInstance("SHA-256").digest(bytes),
        android.util.Base64.NO_WRAP or android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING,
    )
}
