package com.strawio.voicechat.network

import okhttp3.CertificatePinner
import okhttp3.ConnectionSpec
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.TlsVersion
import java.time.Duration
import javax.inject.Inject

class SafeNetworkClientFactory @Inject constructor() {
    fun create(certificatePins: List<CertificatePin> = emptyList()): OkHttpClient {
        val pinnerBuilder = CertificatePinner.Builder()
        certificatePins.forEach { pin ->
            require(pin.backupPins.isNotEmpty()) { "Certificate pinning requires backup pins for rotation" }
            pinnerBuilder.add(pin.host, pin.primaryPin, *pin.backupPins.toTypedArray())
        }
        val tlsSpec = ConnectionSpec.Builder(ConnectionSpec.MODERN_TLS)
            .tlsVersions(TlsVersion.TLS_1_3, TlsVersion.TLS_1_2)
            .build()
        return OkHttpClient.Builder()
            .connectTimeout(Duration.ofSeconds(10))
            .readTimeout(Duration.ofSeconds(10))
            .writeTimeout(Duration.ofSeconds(10))
            .callTimeout(Duration.ofSeconds(20))
            .protocols(listOf(Protocol.HTTP_2, Protocol.HTTP_1_1))
            .connectionSpecs(listOf(tlsSpec))
            .certificatePinner(pinnerBuilder.build())
            .addInterceptor(RedactingLoggingInterceptor())
            .build()
    }
}

data class CertificatePin(val host: String, val primaryPin: String, val backupPins: List<String>)
