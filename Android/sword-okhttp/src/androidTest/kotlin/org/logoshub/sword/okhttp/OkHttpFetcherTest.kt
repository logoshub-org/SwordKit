// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd

package org.logoshub.sword.okhttp

import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import okhttp3.tls.HandshakeCertificates
import okhttp3.tls.HeldCertificate
import okio.Buffer
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.logoshub.sword.SwordNative

/** The fetcher against a local HTTPS server: the bytes, progress, SWORD's error codes, cancellation, and the unverified-certificate rule. */
class OkHttpFetcherTest {
    private class Hooks(var cancelAfter: Int = Int.MAX_VALUE) : SwordNative.HttpHooks(0) {
        var lastTotal = -1L
        var lastCompleted = -1L
        var calls = 0
        override fun progress(total: Long, completed: Long) { lastTotal = total; lastCompleted = completed; calls++ }
        override fun cancelled() = calls >= cancelAfter
    }

    private lateinit var server: MockWebServer
    private lateinit var serverCertificates: HandshakeCertificates
    private lateinit var trustingClient: OkHttpClient

    @Before fun start() {
        val held = HeldCertificate.Builder().commonName("localhost").addSubjectAlternativeName("localhost").build()
        serverCertificates = HandshakeCertificates.Builder().heldCertificate(held).build()
        trustingClient = OkHttpClient.Builder()
            .sslSocketFactory(HandshakeCertificates.Builder().addTrustedCertificate(held.certificate).build().sslSocketFactory(),
                HandshakeCertificates.Builder().addTrustedCertificate(held.certificate).build().trustManager)
            .build()
        server = MockWebServer().apply { useHttps(serverCertificates.sslSocketFactory(), false); start() }
    }

    @After fun stop() { server.shutdown() }

    private fun url(path: String = "/mods.d.tar.gz") = server.url(path).toString()

    private fun error(block: () -> Unit): Int {
        try { block() } catch (e: SwordNative.HttpError) { return e.code }
        fail("expected an HttpError")
        return 0
    }

    @Test fun returnsTheBodyAndReportsProgress() {
        val body = ByteArray(200_000) { (it % 251).toByte() }
        server.enqueue(MockResponse().setBody(Buffer().write(body)))
        val hooks = Hooks()
        val result = OkHttpFetcher(trustingClient).fetch(url(), "", "", 5000, false, hooks)
        assertArrayEquals(body, result)
        assertEquals(body.size.toLong(), hooks.lastTotal)
        assertEquals(body.size.toLong(), hooks.lastCompleted)
        assertTrue(hooks.calls > 1)
    }

    @Test fun sendsBasicAuthWhenGivenAUser() {
        server.enqueue(MockResponse().setBody("ok"))
        OkHttpFetcher(trustingClient).fetch(url(), "user", "secret", 5000, false, Hooks())
        assertEquals("Basic dXNlcjpzZWNyZXQ=", server.takeRequest().getHeader("Authorization"))
    }

    @Test fun mapsStatusesToSwordCodes() {
        server.enqueue(MockResponse().setResponseCode(404))
        server.enqueue(MockResponse().setResponseCode(403))
        server.enqueue(MockResponse().setResponseCode(401))
        val fetcher = OkHttpFetcher(trustingClient)
        assertEquals(-5, error { fetcher.fetch(url(), "", "", 5000, false, Hooks()) })
        assertEquals(-3, error { fetcher.fetch(url(), "", "", 5000, false, Hooks()) })
        assertEquals(-3, error { fetcher.fetch(url(), "", "", 5000, false, Hooks()) })
    }

    @Test fun timesOut() {
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
        assertEquals(-2, error { OkHttpFetcher(trustingClient).fetch(url(), "", "", 600, false, Hooks()) })
    }

    @Test fun stopsWhenSwordCancels() {
        server.enqueue(MockResponse().setBody(Buffer().write(ByteArray(2_000_000))))
        assertEquals(-1, error { OkHttpFetcher(trustingClient).fetch(url(), "", "", 5000, false, Hooks(cancelAfter = 2)) })
    }

    @Test fun anUntrustedCertificateFailsUnlessSwordAllowsIt() {
        server.enqueue(MockResponse().setBody("secret"))
        server.enqueue(MockResponse().setBody("secret"))
        val fetcher = OkHttpFetcher(OkHttpClient())   // the system does not trust the test certificate
        assertEquals(-10, error { fetcher.fetch(url(), "", "", 5000, false, Hooks()) })
        assertEquals("secret", String(fetcher.fetch(url(), "", "", 5000, true, Hooks())))
    }

    @Test fun aBadUrlIsAnOrdinaryFailure() {
        assertEquals(-10, error { OkHttpFetcher().fetch("not a url", "", "", 1000, false, Hooks()) })
    }
}
