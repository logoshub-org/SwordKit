// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd

package org.logoshub.sword.okhttp

import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.net.InetAddress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.logoshub.sword.SwordInstallManager
import org.logoshub.sword.SwordLibrary
import org.logoshub.sword.SwordNative

/** The whole path, over the real network: refresh a source, list it, install a module, read it. Skipped when the network is down. */
class RealInstallTest {
    @Test fun refreshesAndInstallsAModule() {
        assumeTrue("needs the network", try { InetAddress.getByName("www.crosswire.org"); true } catch (e: Exception) { false })
        val cache = InstrumentationRegistry.getInstrumentation().targetContext.cacheDir
        val installDir = File(cache, "real-install").apply { deleteRecursively(); mkdirs() }
        val libraryDir = File(cache, "real-library").apply { deleteRecursively(); mkdirs() }
        var progressed = false
        SwordInstallManager.setHttpFetcher(object : SwordNative.HttpFetcher {
            val inner = OkHttpFetcher()
            override fun fetch(url: String, user: String, password: String, timeoutMs: Long, allowUnverified: Boolean,
                               hooks: SwordNative.HttpHooks): ByteArray {
                println("fetch $url")
                return inner.fetch(url, user, password, timeoutMs, allowUnverified, object : SwordNative.HttpHooks(0) {
                    override fun progress(total: Long, completed: Long) { progressed = true; hooks.progress(total, completed) }
                    override fun cancelled() = hooks.cancelled()
                })
            }
        })
        try {
            SwordInstallManager.open(installDir.path, resetSources = true)!!.use { manager ->
                manager.confirmDisclaimer()
                val source = manager.sources().first { it.type.startsWith("HTTP") }
                assertEquals("refresh " + source, 0, manager.refresh(source.caption))
                SwordLibrary(libraryDir.path).use { library ->
                    val remote = manager.modules(source.caption, library)
                    assertTrue("the source lists modules: ${remote.size}", remote.size > 50)
                    val target = remote.firstOrNull { it.name == "KJV" } ?: remote.first { it.category.contains("Bible") }
                    assertEquals("install ${target.name}", 0, manager.install(target.name, source.caption, library))
                    assertTrue(library.moduleNames().contains(target.name))
                    val chapter = library.readChapter(target.name, if (target.category.contains("Bible")) "John 3" else "Gen 1", plain = true)
                    assertTrue("a chapter reads from the installed module", chapter != null && chapter.verses.isNotEmpty())
                }
                assertTrue(progressed)
            }
        } finally {
            SwordInstallManager.setHttpFetcher(null)
        }
    }
}
