// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd
//
// Swift over the C layer's install manager (plan D134, D137): the sources of modules, what a source offers compared with what is
// installed, installing and removing. The HTTP is the host's (SwordHTTPHost).

import Foundation
import CSwordCore

public final class SwordInstallManager {

	public struct Source: Equatable {
		public var caption: String
		/// "HTTPS", "HTTP" or "FTP" (FTP is not available).
		public var type: String
		public var host: String
		public var directory: String
		public var uid: String
		/// packages/<module>.zip is tried first.
		public var packagePreference: Bool

		public init(caption: String, type: String, host: String, directory: String, uid: String, packagePreference: Bool) {
			self.caption = caption
			self.type = type
			self.host = host
			self.directory = directory
			self.uid = uid
			self.packagePreference = packagePreference
		}
	}

	/// What a source offers, compared with what is installed.
	public struct RemoteModule: Equatable {
		public enum Status { case new, updated, older, same }
		public var name: String
		public var description: String
		public var category: String
		public var language: String
		public var version: String
		public var status: Status

		package init(name: String, description: String, category: String, language: String, version: String, status: Status) {
			self.name = name
			self.description = description
			self.category = category
			self.language = language
			self.version = version
			self.status = status
		}
	}

	/// SWORD's message ("update" while bytes arrive), the bytes in all and the bytes so far.
	public typealias StatusHandler = (_ message: String, _ total: UInt, _ completed: UInt) -> Void

	private let handle: SWXHANDLE
	private let statusBox: StatusBox
	private let lock = NSRecursiveLock()

	private final class StatusBox {
		package var handler: StatusHandler?
		package init(_ handler: StatusHandler?) { self.handler = handler }
	}

	/// Opens the install manager for a folder (its InstallMgr.conf lives there). The default sources are written when the file is
	/// missing, or when `resetSources` is true.
	public init?(directory: String, resetSources: Bool = false, status: StatusHandler? = nil) {
		let box = StatusBox(status)
		let opened = swx_install_new(directory, resetSources ? 1 : 0, { message, total, completed, context in
			Unmanaged<StatusBox>.fromOpaque(context!).takeUnretainedValue().handler?(message.map { String(cString: $0) } ?? "", total, completed)
		}, Unmanaged.passUnretained(box).toOpaque())
		guard opened != 0 else { return nil }
		handle = opened
		statusBox = box
	}

	deinit { swx_install_delete(handle) }

	/// Who hears of the bytes as they arrive (set by whoever is showing progress; nil for none).
	public var statusHandler: StatusHandler? {
		get { statusBox.handler }
		set { statusBox.handler = newValue }
	}

	/// Runs `body` with the install manager's handle while the installer is locked.
	package func lockedHandle<T>(_ body: (SWXHANDLE) -> T) -> T {
		lock.lock()
		defer { lock.unlock() }
		return body(handle)
	}

	// MARK: Sources

	public var sources: [Source] {
		lock.lock()
		defer { lock.unlock() }
		var count: Int32 = 0
		guard let list = swx_install_sources(handle, &count) else { return [] }
		defer { swx_free_sources(list, count) }
		return (0..<Int(count)).map {
			Source(caption: String(cString: list[$0].caption), type: String(cString: list[$0].type), host: String(cString: list[$0].source),
			       directory: String(cString: list[$0].directory), uid: String(cString: list[$0].uid), packagePreference: list[$0].package_preference != 0)
		}
	}

	@discardableResult
	public func add(_ source: Source) -> Bool {
		lock.lock()
		defer { lock.unlock() }
		var entry = swx_source(type: strdup(source.type), caption: strdup(source.caption), source: strdup(source.host),
		                      directory: strdup(source.directory), uid: strdup(source.uid), package_preference: source.packagePreference ? 1 : 0)
		defer { free(entry.type); free(entry.caption); free(entry.source); free(entry.directory); free(entry.uid) }
		return swx_install_add_source(handle, &entry) == 0
	}

	@discardableResult
	public func remove(caption: String) -> Bool {
		lock.lock()
		defer { lock.unlock() }
		return swx_install_remove_source(handle, caption) == 0
	}

	// MARK: Installing

	/// Whether the reader has agreed to downloading modules.
	public private(set) var disclaimerConfirmed = false

	/// The reader has been shown the disclaimer for downloading modules.
	public func confirmDisclaimer() {
		lock.lock()
		defer { lock.unlock() }
		disclaimerConfirmed = true
		org_crosswire_sword_InstallMgr_setUserDisclaimerConfirmed(handle)
	}

	/// Refreshes the list of CrossWire's sources from the master list. 0 on success.
	public func refreshSourceList() -> Int {
		lock.lock()
		defer { lock.unlock() }
		return Int(org_crosswire_sword_InstallMgr_syncConfig(handle))
	}

	/// Downloads a source's list of modules. 0 on success; otherwise SWORD's code (-5 an HTTP error, -2 timed out, ...).
	public func refresh(sourceCaption caption: String) -> Int {
		lock.lock()
		defer { lock.unlock() }
		return Int(org_crosswire_sword_InstallMgr_refreshRemoteSource(handle, caption))
	}

	/// The modules a refreshed source offers, each compared with the installed copy in `library`.
	public func modules(sourceCaption caption: String, comparedWith library: SwordLibrary) -> [RemoteModule] {
		lock.lock()
		defer { lock.unlock() }
		return library.withManager { manager in
			var result: [RemoteModule] = []
			var info = org_crosswire_sword_InstallMgr_getRemoteModInfoList(handle, manager, caption)
			while let entry = info, let name = entry.pointee.name {
				func text(_ pointer: UnsafeMutablePointer<CChar>?) -> String { pointer.map { String(cString: $0) } ?? "" }
				let status: RemoteModule.Status
				switch text(entry.pointee.delta) {
				case "*": status = .new
				case "+": status = .updated
				case "-": status = .older
				default: status = .same
				}
				result.append(RemoteModule(name: String(cString: name), description: text(entry.pointee.description), category: text(entry.pointee.category),
				                           language: text(entry.pointee.language), version: text(entry.pointee.version), status: status))
				info = entry + 1
			}
			return result
		}
	}

	/// Downloads and installs a module from a refreshed source into the library. 0 on success.
	public func install(module name: String, sourceCaption caption: String, into library: SwordLibrary) -> Int {
		lock.lock()
		defer { lock.unlock() }
		let result = library.withManager { Int(org_crosswire_sword_InstallMgr_remoteInstallModule(handle, $0, caption, name)) }
		library.reload()
		return result
	}

	/// Removes an installed module's files. 0 on success.
	public func uninstall(module name: String, from library: SwordLibrary) -> Int {
		lock.lock()
		defer { lock.unlock() }
		let result = library.withManager { Int(org_crosswire_sword_InstallMgr_uninstallModule(handle, $0, name)) }
		library.reload()
		return result
	}
}

// MARK: Modules a source offers, not yet installed

extension SwordInstallManager {

	/// The facts of a module a refreshed source offers, for as long as `body` runs (the source's own manager holds the module).
	public func withRemoteFacts<T>(module name: String, sourceCaption caption: String, library: SwordLibrary,
	                        _ body: (SwordLibrary.ModuleFacts) -> T) -> T? {
		let handle = SWXHANDLE(lockedHandle { org_crosswire_sword_InstallMgr_getRemoteModuleByName($0, caption, name) })
		guard handle != 0, let info = SwordLibrary.info(handle: handle, name: name) else { return nil }
		let facts = SwordLibrary.ModuleFacts(
			info: info, config: { SwordLibrary.configEntry($0, handle: handle) },
			has: { swx_module_has_feature(handle, $0) != 0 },
			locked: library.isLocked(info))
		return body(facts)
	}

	/// The module's About fields as the source describes it, with the version installed beside it.
	public func aboutFields(forRemoteModule name: String, sourceCaption caption: String, currentVersion: String?, library: SwordLibrary) -> [[String: Any]] {
		withRemoteFacts(module: name, sourceCaption: caption, library: library) { SwordLibrary.aboutFields($0, currentVersion: currentVersion) } ?? []
	}
}
