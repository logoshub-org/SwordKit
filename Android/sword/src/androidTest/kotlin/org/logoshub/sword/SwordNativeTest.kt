// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd

package org.logoshub.sword

import org.junit.Assert.*
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Test
import java.io.File

/**
 * Runs on a device or an emulator against modules pushed by Tools/run_android_tests.sh to /data/local/tmp/sword-test (KJV, a Strong's
 * dictionary). The modules are local test data and are never committed.
 */
class SwordNativeTest {
    private val pushed = File("/data/local/tmp/sword-test")
    // the app may read /data/local/tmp but not write there (an index is written beside its module): work on a copy in the app's cache
    private val folder: String by lazy {
        val dir = File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "sword-test")
        dir.deleteRecursively()
        pushed.copyRecursively(dir, overwrite = true)
        dir.path
    }

    private fun library() = SwordLibrary(folder)

    private fun SwordLibrary.kjv() = moduleNames().first { it.equals("KJV", ignoreCase = true) }

    @Test fun listsModules() {
        library().use { lib ->
            val names = lib.moduleNames()
            assertTrue("modules: $names", names.any { it.equals("KJV", ignoreCase = true) })
        }
    }

    @Test fun moduleFacts() {
        library().use { lib ->
            val info = lib.info(lib.kjv())!!
            assertTrue(info.verseKeyed)
            assertEquals("KJV", info.versification)
            assertNotNull(info.description)
            assertNull("an unencrypted module has no cipher key", info.cipherKey)
        }
    }

    @Test fun readsAChapterRawAndPlain() {
        library().use { lib ->
            val raw = lib.readChapter(lib.kjv(), "John 3")!!
            assertEquals("John", raw.osisBook)
            assertEquals(3, raw.chapter)
            assertEquals(36, raw.verses.last().first)
            val verse16 = raw.verses.first { it.first == 16 }.second
            assertTrue("raw text is the module's own OSIS markup: $verse16", verse16.contains("<w ") && verse16.contains("loved"))
            val plain = lib.readChapter(lib.kjv(), "John 3", plain = true)!!
            val plain16 = plain.verses.first { it.first == 16 }.second
            assertFalse("plain text has no markup: $plain16", plain16.contains("<"))
            assertTrue(plain16, plain16.contains("loved the world"))
        }
    }

    @Test fun strippedAndPassages() {
        library().use { lib ->
            assertTrue(lib.readStripped(lib.kjv(), "John 3:16")!!.contains("only begotten Son"))
            assertEquals(listOf("John 3:16", "John 3:17", "John 3:18"), SwordVersification.parsePassage("John 3:16-18"))
        }
    }

    @Test fun searchesWithARegularExpressionThenAnIndex() {
        library().use { lib ->
            val kjv = lib.kjv()
            lib.deleteSearchIndex(kjv)
            assertFalse(lib.hasSearchIndex(kjv))
            val plain = lib.search(kjv, "Jesus wept", SwordSearchRange.NEW_TESTAMENT)!!
            assertFalse("no index yet", plain.usedIndex)
            assertTrue(plain.keys.toString(), plain.keys.contains("John 11:35"))

            var last = -1
            assertEquals(0, lib.createSearchIndex(kjv) { last = it })
            assertTrue("progress was reported up to the end ($last)", last >= 90)
            assertTrue(lib.hasSearchIndex(kjv))
            val indexed = lib.search(kjv, "\"Jesus wept\"", SwordSearchRange.ALL)!!
            assertTrue("used the index", indexed.usedIndex)
            assertTrue(indexed.keys.toString(), indexed.keys.contains("John 11:35"))
            val book = lib.search(kjv, "wept", SwordSearchRange.BOOK, bookReference = "John 3")!!
            assertTrue(book.keys.all { it.startsWith("John") })
            lib.deleteSearchIndex(kjv)
        }
    }

    @Test fun dictionaryEntries() {
        library().use { lib ->
            val dict = lib.moduleNames().firstOrNull { lib.info(it)?.verseKeyed == false }
            assertNotNull("a dictionary module is installed", dict)
            val keys = lib.dictionaryKeys(dict!!)
            assertTrue(keys.size > 100)
            val entry = lib.readEntry(dict, keys.first())
            assertNotNull(entry)
            assertTrue(entry!!.second.isNotEmpty())
        }
    }

    @Test fun versification() {
        assertTrue(SwordVersification.systems().contains("KJV"))
        val books = SwordVersification.books("KJV")
        assertEquals(66, books.size)
        assertEquals("Gen", books[0].osisName)
        assertEquals(50, books[0].chapters)
        assertEquals(31, books[0].versesPerChapter[0])
        assertTrue(books.last().newTestament)
        assertEquals("Genesis", SwordVersification.englishBookName("Genesis"))
    }

    @Test fun unicodeAcrossTheBoundary() {
        // characters outside the BMP break NewStringUTF: they must survive both ways
        library().use { lib ->
            assertNull(lib.readStripped("NoSuchModule 😀", "John 3:16"))
            assertEquals("😀 א", SwordVersification.englishBookName("😀 א"))
        }
    }

    @Test fun theHostFetchesForTheInstallManager() {
        val dir = File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "install-test").apply { deleteRecursively(); mkdirs() }
        val urls = mutableListOf<String>()
        var progressSeen = false
        SwordInstallManager.setHttpFetcher(object : SwordNative.HttpFetcher {
            override fun fetch(url: String, user: String, password: String, timeoutMs: Long, allowUnverified: Boolean,
                               hooks: SwordNative.HttpHooks): ByteArray {
                urls += url
                hooks.progress(10, 5)
                progressSeen = true
                assertFalse(hooks.cancelled())
                throw SwordNative.HttpError(-3)
            }
        })
        try {
            SwordInstallManager.open(dir.path, resetSources = true)!!.use { manager ->
                val sources = manager.sources()
                assertTrue("default sources are written", sources.isNotEmpty())
                manager.confirmDisclaimer()
                val result = manager.refresh(sources.first { it.type.startsWith("HTTP") }.caption)
                assertTrue("the fetch failed, so the refresh did: $result", result != 0)
                assertTrue("SWORD asked the host for a URL: $urls", urls.isNotEmpty() && urls.first().startsWith("http"))
                assertTrue(progressSeen)

                assertTrue(manager.add(SwordSource("Test", "HTTPS", "example.org", "/sword", "test-uid", false)))
                assertTrue(manager.sources().any { it.caption == "Test" })
                assertTrue(manager.remove("Test"))
                assertFalse(manager.sources().any { it.caption == "Test" })
            }
        } finally {
            SwordInstallManager.setHttpFetcher(null)
        }
    }
}
