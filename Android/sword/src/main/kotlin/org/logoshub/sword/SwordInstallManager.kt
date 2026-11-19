// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd

package org.logoshub.sword

/** One source of modules (a line of InstallMgr.conf). */
data class SwordSource(
    val caption: String, val type: String, val host: String, val directory: String, val uid: String, val packagePreference: Boolean,
)

data class SwordRemoteModule(
    val name: String, val description: String, val category: String, val language: String, val version: String, val status: Status,
) {
    enum class Status { NEW, UPDATED, OLDER, SAME }
}

/**
 * A module a refreshed source offers, read from the source's own copy of its conf: what a download screen shows before the module is
 * installed (its markup, size, licence, About page). Valid only inside [SwordInstallManager.withRemoteModule]'s body, as the source's
 * manager holds the module; keep the values, not this.
 */
class SwordRemoteModuleFacts internal constructor(private val module: Long, val info: SwordModuleInfo) {
    /** Encrypted and offered without a key: it needs one to be read once installed (an installed copy may have been given one since). */
    val locked: Boolean get() = info.cipherKey != null && info.cipherKey.isEmpty()

    /** An entry of the module's conf ("SourceType", "InstallSize", "DataPath", "About"), or null when it has none. */
    fun configEntry(key: String): String? = SwordNative.moduleConfigEntry(module, key)

    fun hasFeature(feature: String): Boolean = SwordNative.moduleHasFeature(module, feature)
}

/**
 * SWORD's install manager. SWORD does the logic; the host does the HTTP: register a fetcher with [setHttpFetcher] before refreshing
 * a source or installing (HttpURLConnection or OkHttp; it reports progress and cancellation through the hooks it is given).
 */
class SwordInstallManager private constructor(private var handle: Long) : AutoCloseable {
    companion object {
        fun setHttpFetcher(fetcher: SwordNative.HttpFetcher?) = SwordNative.setHttpFetcher(fetcher)

        /** The install manager for a folder (its InstallMgr.conf lives there); the default sources are written when it has none. */
        fun open(directory: String, resetSources: Boolean = false, status: SwordNative.StatusListener? = null): SwordInstallManager? {
            val h = SwordNative.installNew(directory, resetSources, status)
            return if (h == 0L) null else SwordInstallManager(h)
        }
    }

    private val lock = Any()

    override fun close() = synchronized(lock) {
        if (handle != 0L) { SwordNative.installDelete(handle); handle = 0 }
    }

    fun sources(): List<SwordSource> = synchronized(lock) {
        val a = SwordNative.installSources(handle) ?: return emptyList()
        (a.indices step 6).map { SwordSource(a[it + 1], a[it], a[it + 2], a[it + 3], a[it + 4], a[it + 5] == "1") }
    }

    fun add(source: SwordSource): Boolean = synchronized(lock) {
        SwordNative.installAddSource(handle, arrayOf(source.type, source.caption, source.host, source.directory, source.uid,
            if (source.packagePreference) "1" else "0"))
    }

    fun remove(caption: String): Boolean = synchronized(lock) { SwordNative.installRemoveSource(handle, caption) }

    fun confirmDisclaimer() = synchronized(lock) { SwordNative.installSetDisclaimerConfirmed(handle) }

    fun syncConfig(): Int = synchronized(lock) { SwordNative.installSyncConfig(handle) }

    /** Fetches the source's module list. 0 on success. */
    fun refresh(caption: String): Int = synchronized(lock) { SwordNative.installRefresh(handle, caption) }

    fun modules(caption: String, comparedWith: SwordLibrary): List<SwordRemoteModule> = synchronized(lock) {
        val a = SwordNative.installRemoteModules(handle, comparedWith.manager, caption)
        (a.indices step 6).map {
            SwordRemoteModule(a[it] ?: "", a[it + 1] ?: "", a[it + 2] ?: "", a[it + 3] ?: "", a[it + 4] ?: "", when (a[it + 5]) {
                "*" -> SwordRemoteModule.Status.NEW
                "+" -> SwordRemoteModule.Status.UPDATED
                "-" -> SwordRemoteModule.Status.OLDER
                else -> SwordRemoteModule.Status.SAME
            })
        }
    }

    /**
     * The facts of a module a refreshed source offers, for as long as [body] runs, or null when the source has no such module (or has not
     * been refreshed). The same as the Swift API's `withRemoteFacts`.
     */
    fun <T> withRemoteModule(module: String, caption: String, body: (SwordRemoteModuleFacts) -> T): T? = synchronized(lock) {
        val remote = SwordNative.installRemoteModule(handle, caption, module)
        if (remote == 0L) return@synchronized null
        val info = infoOf(remote) ?: return@synchronized null
        body(SwordRemoteModuleFacts(remote, info))
    }

    /** Downloads and installs a module of a refreshed source into the library. 0 on success. */
    fun install(module: String, caption: String, into: SwordLibrary): Int = synchronized(lock) {
        val result = SwordNative.installModule(handle, into.manager, caption, module)
        if (result == 0) into.reload()
        result
    }

    fun uninstall(module: String, from: SwordLibrary): Int = synchronized(lock) {
        val result = SwordNative.installUninstall(handle, from.manager, module)
        if (result == 0) from.reload()
        result
    }
}
