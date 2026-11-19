// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd

package org.logoshub.sword

/** The facts about a module the readers need (the same as SwordProvider's SwordModuleInfo). */
/** A module's facts from its handle: an installed module's, or the copy a source holds of one it offers. */
internal fun infoOf(module: Long): SwordModuleInfo? {
    val a = SwordNative.moduleInfo(module) ?: return null
    return SwordModuleInfo(a[0], a[1] ?: "KJV", a[2], a[3], a[4], a[5], a[6], a[7],
        a[8] == "1", a[9] == "1", a[10] == "1", a[11] == "1", a[12] == "1", a[13] == "1", a[14] == "1")
}

data class SwordModuleInfo(
    val sourceType: String?,
    val versification: String,
    val type: String?,
    val category: String?,
    val description: String?,
    val language: String?,
    val version: String?,
    /** null when the module is not encrypted, empty when it is locked. */
    val cipherKey: String?,
    val rightToLeft: Boolean,
    val unicode: Boolean,
    val osisQToTick: Boolean,
    val verseKeyed: Boolean,
    val declaresGreekAccents: Boolean,
    val declaresHebrewPoints: Boolean,
    val declaresCantillation: Boolean,
)

/** One chapter of a verse-keyed module. Verse 0 is the chapter's introduction (often empty). */
data class SwordChapter(val osisBook: String, val chapter: Int, val verses: List<Pair<Int, String>>)

data class SwordBook(val name: String, val osisName: String, val newTestament: Boolean, val versesPerChapter: List<Int>) {
    val chapters: Int get() = versesPerChapter.size
}

enum class SwordSearchRange { ALL, OLD_TESTAMENT, NEW_TESTAMENT, BOOK }

class SwordSearchResult(val keys: List<String>, val usedIndex: Boolean)

/** Versification systems and their books: not tied to a library. */
object SwordVersification {
    fun systems(): List<String> = SwordNative.versificationSystems().toList()

    fun books(system: String): List<SwordBook> {
        val flat = SwordNative.versificationBooks(system) ?: return emptyList()
        val books = mutableListOf<SwordBook>()
        var i = 0
        while (i < flat.size) {
            val chapters = flat[i + 3].toInt()
            books += SwordBook(flat[i], flat[i + 1], flat[i + 2] == "1", (0 until chapters).map { flat[i + 4 + it].toInt() })
            i += 4 + chapters
        }
        return books
    }

    fun englishBookName(name: String): String = SwordNative.englishBookName(name)

    /** The verses a passage names ("John 3:16-18, Rom 5"), as SWORD writes them. */
    fun parsePassage(reference: String, versification: String = ""): List<String> =
        SwordNative.parsePassage(reference, versification)?.toList() ?: emptyList()

    /** Points SWORD at a folder of locale files and picks the first preferred language it has. */
    fun initLocale(localesFolder: String, preferred: List<String>) = SwordNative.initLocale(localesFolder, preferred.toTypedArray())
}

/** The installed modules of a SWORD library folder (mods.d and modules). Close it when done. */
class SwordLibrary(val path: String) : AutoCloseable {
    internal var manager: Long = SwordNative.mgrNew(path)
        private set

    private val lock = Any()
    private val cipherKeys = mutableMapOf<String, String>()

    init { require(manager != 0L) { "SWORD could not open $path" } }

    override fun close() = synchronized(lock) {
        if (manager != 0L) { SwordNative.mgrDelete(manager); manager = 0 }
    }

    /** Opens the folder again, after modules were installed or removed. */
    fun reload() = synchronized(lock) {
        SwordNative.mgrDelete(manager)
        manager = SwordNative.mgrNew(path)
        for ((name, key) in cipherKeys) SwordNative.mgrSetCipherKey(manager, name, key)
    }

    fun moduleNames(): List<String> = synchronized(lock) { SwordNative.mgrModuleNames(manager).toList() }

    private fun <T> withModule(name: String, body: (Long) -> T?): T? = synchronized(lock) {
        val module = SwordNative.mgrModule(manager, name)
        if (module == 0L) null else body(module)
    }

    fun info(name: String): SwordModuleInfo? = withModule(name) { infoOf(it) }

    fun configEntry(name: String, key: String): String? = withModule(name) { SwordNative.moduleConfigEntry(it, key) }

    fun hasFeature(name: String, feature: String): Boolean = withModule(name) { SwordNative.moduleHasFeature(it, feature) } ?: false

    /** Installs every module of an unpacked raw module folder (mods.d and modules); the names installed. */
    fun installFromFolder(folder: String): List<String> = synchronized(lock) {
        val names = SwordNative.installFromFolder(manager, folder)?.toList() ?: emptyList()
        if (names.isNotEmpty()) reload()
        names
    }

    fun setCipherKey(name: String, key: String?) = synchronized(lock) {
        if (key == null) cipherKeys.remove(name) else cipherKeys[name] = key
        SwordNative.mgrSetCipherKey(manager, name, key ?: "")
    }

    fun setGlobalOption(option: String, on: Boolean) = synchronized(lock) {
        SwordNative.mgrSetGlobalOption(manager, option, if (on) "On" else "Off")
    }

    /** A whole chapter in one call: raw (the module's markup) or SWORD's plain text. Null when the module is not verse-keyed. */
    fun readChapter(name: String, reference: String, plain: Boolean = false): SwordChapter? = withModule(name) { m ->
        val a = SwordNative.readChapter(m, reference, plain) ?: return@withModule null
        SwordChapter(a[0], a[1].toInt(), (2 until a.size step 2).map { a[it].toInt() to a[it + 1] })
    }

    /** An entry of a dictionary-like module: the key as the module names it, and the raw entry. */
    fun readEntry(name: String, key: String): Pair<String, String>? = withModule(name) { m ->
        SwordNative.readEntry(m, key)?.let { it[0] to it[1] }
    }

    fun readStripped(name: String, key: String): String? = withModule(name) { SwordNative.readStripped(it, key) }

    fun dictionaryKeys(name: String): List<String> = withModule(name) { SwordNative.dictionaryKeys(it)?.toList() } ?: emptyList()

    fun hasSearchIndex(name: String): Boolean = withModule(name) { SwordNative.hasSearchIndex(it) } ?: false

    fun search(
        name: String, term: String, range: SwordSearchRange = SwordSearchRange.ALL, bookReference: String = "", versification: String = "",
    ): SwordSearchResult? = withModule(name) { m ->
        val a = SwordNative.search(m, term, range.ordinal, bookReference, versification) ?: return@withModule null
        SwordSearchResult(a.drop(1), a[0] == "1")
    }

    /** Builds the module's CLucene index (seconds to minutes: call it off the main thread). 0 on success. */
    fun createSearchIndex(name: String, progress: SwordNative.ProgressListener? = null): Int =
        withModule(name) { SwordNative.createSearchIndex(it, progress) } ?: -1

    fun deleteSearchIndex(name: String) { withModule(name) { SwordNative.deleteSearchIndex(it) } }
}
