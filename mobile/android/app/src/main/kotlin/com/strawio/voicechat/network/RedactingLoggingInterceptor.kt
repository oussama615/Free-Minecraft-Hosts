package com.strawio.voicechat.network

import com.strawio.voicechat.BuildConfig
import okhttp3.Interceptor
import okhttp3.Response

class RedactingLoggingInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        if (BuildConfig.DEBUG) {
            val safeHeaders = request.headers.newBuilder()
                .set("Authorization", "<redacted>")
                .set("Cookie", "<redacted>")
                .build()
            android.util.Log.d("StrawIO.Network", "${request.method} ${request.url.redact()} headers=${safeHeaders.names()}")
        }
        return chain.proceed(request)
    }
}

object SensitiveDataRedactor {
    private val uuidRegex = Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
    private val tokenRegex = Regex("(?i)(token|authorization|secret|key)=([^&\\s]+)")

    fun redact(input: String): String = input
        .replace(uuidRegex) { match -> match.value.take(8) + "…<redacted>" }
        .replace(tokenRegex) { match -> match.groupValues[1] + "=<redacted>" }
        .take(500)
}
