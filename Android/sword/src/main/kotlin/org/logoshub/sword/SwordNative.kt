// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd

package org.logoshub.sword

/**
 * The JNI over SWORD's C layer (Core/android/sword_jni.cpp): handles are Longs, results are strings and arrays of strings in the
 * orders documented on each function in the C++ file. SwordLibrary and SwordInstallManager give them types; use those.
 */
object SwordNative {
    init {
        System.loadLibrary("sword_android")
    }

    /** Called while a search index is built. */
    fun interface ProgressListener { fun onProgress(percent: Int) }

    /** SWORD's install messages: its message, and the bytes in all and so far. */
    fun interface StatusListener { fun onStatus(message: String?, total: Long, completed: Long) }

    /** A failed fetch, with SWORD's code: -1 cancelled, -2 timed out, -3 access denied, -5 an HTTP error status, -10 anything else. */
    class HttpError(@JvmField val code: Int) : Exception("HTTP fetch failed, SWORD code $code")

    /** What a fetcher may do while it works: report progress and ask whether the user has cancelled. Valid only during `fetch`. */
    open class HttpHooks(private val address: Long) {
        open fun progress(total: Long, completed: Long) = hookProgress(address, total, completed)
        open fun cancelled(): Boolean = hookCancelled(address)
    }

    /** The host's HTTP client: fetches one URL completely into memory, or throws HttpError. */
    interface HttpFetcher {
        fun fetch(url: String, user: String, password: String, timeoutMs: Long, allowUnverified: Boolean, hooks: HttpHooks): ByteArray
    }

    @JvmStatic external fun mgrNew(path: String): Long
    @JvmStatic external fun mgrDelete(mgr: Long)
    @JvmStatic external fun mgrModuleNames(mgr: Long): Array<String>
    @JvmStatic external fun mgrModule(mgr: Long, name: String): Long
    @JvmStatic external fun mgrSetCipherKey(mgr: Long, name: String, key: String)
    @JvmStatic external fun mgrSetGlobalOption(mgr: Long, option: String, value: String)

    /** source type, versification, type, category, description, language, version, cipher key (null: not encrypted), then flags "0"/"1":
     *  right to left, unicode, OSIS q to tick, verse keyed, Greek accents, Hebrew points, cantillation. */
    @JvmStatic external fun moduleInfo(module: Long): Array<String?>?
    @JvmStatic external fun moduleConfigEntry(module: Long, key: String): String?
    @JvmStatic external fun moduleHasFeature(module: Long, feature: String): Boolean
    @JvmStatic external fun installFromFolder(mgr: Long, folder: String): Array<String>?
    @JvmStatic external fun initLocale(folder: String, preferred: Array<String>)

    /** OSIS book, chapter, then each verse's number and text. */
    @JvmStatic external fun readChapter(module: Long, reference: String, plain: Boolean): Array<String>?
    /** The key as the module names it, and the raw entry. */
    @JvmStatic external fun readEntry(module: Long, key: String): Array<String>?
    @JvmStatic external fun readStripped(module: Long, key: String): String?
    @JvmStatic external fun dictionaryKeys(module: Long): Array<String>?
    @JvmStatic external fun parsePassage(reference: String, versification: String): Array<String>?
    @JvmStatic external fun englishBookName(name: String): String
    @JvmStatic external fun versificationSystems(): Array<String>
    /** Each book: name, OSIS name, "1" for the New Testament, the number of chapters, then the verses of each chapter. */
    @JvmStatic external fun versificationBooks(system: String): Array<String>?

    @JvmStatic external fun hasSearchIndex(module: Long): Boolean
    /** "1" or "0" for whether an index was used, then the hits. */
    @JvmStatic external fun search(module: Long, term: String, range: Int, bookReference: String, versification: String): Array<String>?
    @JvmStatic external fun createSearchIndex(module: Long, listener: ProgressListener?): Int
    @JvmStatic external fun deleteSearchIndex(module: Long)

    @JvmStatic external fun setHttpFetcher(fetcher: HttpFetcher?)
    @JvmStatic external fun hookProgress(hooks: Long, total: Long, completed: Long)
    @JvmStatic external fun hookCancelled(hooks: Long): Boolean
    @JvmStatic external fun installNew(baseDir: String, resetSources: Boolean, listener: StatusListener?): Long
    @JvmStatic external fun installDelete(install: Long)
    /** Each source: type, caption, host, directory, uid, "1" when packages are tried first. */
    @JvmStatic external fun installSources(install: Long): Array<String>?
    @JvmStatic external fun installAddSource(install: Long, fields: Array<String>): Boolean
    @JvmStatic external fun installRemoveSource(install: Long, caption: String): Boolean
    @JvmStatic external fun installSetDisclaimerConfirmed(install: Long)
    @JvmStatic external fun installSyncConfig(install: Long): Int
    @JvmStatic external fun installRefresh(install: Long, caption: String): Int
    /** Each remote module: name, description, category, language, version, delta ("*" new, "+" updated, "-" older, "" same). */
    @JvmStatic external fun installRemoteModules(install: Long, mgr: Long, caption: String): Array<String?>
    @JvmStatic external fun installRemoteModule(install: Long, caption: String, name: String): Long
    @JvmStatic external fun installModule(install: Long, mgr: Long, caption: String, name: String): Int
    @JvmStatic external fun installUninstall(install: Long, mgr: Long, name: String): Int
}
