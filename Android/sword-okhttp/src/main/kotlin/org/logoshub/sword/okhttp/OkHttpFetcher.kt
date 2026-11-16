// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd

package org.logoshub.sword.okhttp

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InterruptedIOException
import java.net.SocketTimeoutException
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.SSLContext
import javax.net.ssl.X509TrustManager
import okhttp3.Credentials
import okhttp3.OkHttpClient
import okhttp3.Request
import org.logoshub.sword.SwordNative

/**
 * Fetches for SWORD's install manager with OkHttp: one URL, completely into memory, with progress and cancellation reported through
 * the hooks SWORD gives. Failures are SWORD's own codes (see [SwordNative.HttpError]). A certificate the system rejects is accepted
 * only when SWORD asks for it (an install source the user marked as unverified), as on iOS.
 *
 * Register it once: `SwordInstallManager.setHttpFetcher(OkHttpFetcher())`.
 */
class OkHttpFetcher(private val client: OkHttpClient = OkHttpClient()) : SwordNative.HttpFetcher {
    private val unverifiedClient: OkHttpClient by lazy {
        val trustAll = object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
        }
        val context = SSLContext.getInstance("TLS").apply { init(null, arrayOf(trustAll), SecureRandom()) }
        client.newBuilder().sslSocketFactory(context.socketFactory, trustAll).hostnameVerifier { _, _ -> true }.build()
    }

    override fun fetch(
        url: String, user: String, password: String, timeoutMs: Long, allowUnverified: Boolean, hooks: SwordNative.HttpHooks,
    ): ByteArray {
        val request = try {
            Request.Builder().url(url).apply { if (user.isNotEmpty()) header("Authorization", Credentials.basic(user, password)) }.build()
        } catch (e: IllegalArgumentException) {
            throw SwordNative.HttpError(-10)
        }
        val timeout = if (timeoutMs > 0) timeoutMs else DEFAULT_TIMEOUT_MS
        val call = (if (allowUnverified) unverifiedClient else client).newBuilder()
            .connectTimeout(timeout, java.util.concurrent.TimeUnit.MILLISECONDS)
            .readTimeout(timeout, java.util.concurrent.TimeUnit.MILLISECONDS)
            .build().newCall(request)
        try {
            call.execute().use { response ->
                if (response.code == 401 || response.code == 403) throw SwordNative.HttpError(-3)
                if (!response.isSuccessful) throw SwordNative.HttpError(-5)
                val body = response.body ?: throw SwordNative.HttpError(-10)
                val total = body.contentLength().coerceAtLeast(0)
                val out = ByteArrayOutputStream(if (total in 1..MAX_PREALLOCATED) total.toInt() else 8192)
                val buffer = ByteArray(32 * 1024)
                val source = body.byteStream()
                var completed = 0L
                while (true) {
                    if (hooks.cancelled()) { call.cancel(); throw SwordNative.HttpError(-1) }
                    val n = source.read(buffer)
                    if (n < 0) break
                    out.write(buffer, 0, n)
                    completed += n
                    hooks.progress(total, completed)
                }
                return out.toByteArray()
            }
        } catch (e: SwordNative.HttpError) {
            throw e
        } catch (e: SocketTimeoutException) {
            throw SwordNative.HttpError(-2)
        } catch (e: InterruptedIOException) {
            throw SwordNative.HttpError(if (call.isCanceled()) -1 else -2)
        } catch (e: IOException) {
            throw SwordNative.HttpError(if (call.isCanceled()) -1 else -10)
        }
    }

    private companion object {
        const val DEFAULT_TIMEOUT_MS = 30_000L
        const val MAX_PREALLOCATED = 64L * 1024 * 1024
    }
}
