// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd
// Rewritten from the key list of SwordDictionary.mm (PocketSword, Nic Carter and CrossWire Bible Society)

import Foundation
import CSwordCore

extension SwordLibrary {

	/// Where a dictionary's key list is kept: by module and version, in the same file the Objective-C wrapper wrote (a property list
	/// of the keys), so the lists already made are used.
	package func keyCachePath(forModule name: String) -> String {
		let version = configEntry("Version", module: name) ?? "0.0"
		return (keyCacheFolder as NSString).appendingPathComponent("cache-\(name)-\(version)")
	}

	/// Whether the keys have been read this run.
	public func dictionaryKeysLoaded(_ name: String) -> Bool {
		lock.lock()
		defer { lock.unlock() }
		return dictionaryKeysInMemory[name] != nil
	}

	/// Whether the keys were read before and kept: they can be had at once.
	public func dictionaryKeysCached(_ name: String) -> Bool {
		FileManager.default.fileExists(atPath: keyCachePath(forModule: name))
	}

	/// Every key of a dictionary, capitalised as the app has always shown them. The first reading of a large dictionary takes a while
	/// (call it off the main thread); it is kept for the next run.
	public func dictionaryKeys(_ name: String) -> [String] {
		lock.lock()
		if let keys = dictionaryKeysInMemory[name] { lock.unlock(); return keys }
		lock.unlock()

		let path = keyCachePath(forModule: name)
		var keys = (NSArray(contentsOfFile: path) as? [String]) ?? []
		if keys.isEmpty {
			keys = readDictionaryKeys(name).map(\.capitalized)
			(keys as NSArray).write(toFile: path, atomically: false)
		}
		lock.lock()
		dictionaryKeysInMemory[name] = keys
		lock.unlock()
		return keys
	}

	private func readDictionaryKeys(_ name: String) -> [String] {
		withModule(name) { module -> [String] in
			var count: Int32 = 0
			guard let list = swx_dictionary_keys(module, &count) else { return [] }
			defer { swx_free_strings(list, count) }
			return (0..<Int(count)).compactMap { index in
				guard let pointer = list[index] else { return nil }
				// UTF-8 as a rule; a module that is not Unicode gives Latin-1.
				return String(validatingUTF8: pointer) ?? String(cString: pointer, encoding: .isoLatin1)
			}
		} ?? []
	}

	/// Gives the memory back (the keys of one dictionary, or all of them); the kept copy stays.
	public func releaseDictionaryKeys(_ name: String? = nil) {
		lock.lock()
		defer { lock.unlock() }
		if let name { dictionaryKeysInMemory[name] = nil } else { dictionaryKeysInMemory = [:] }
	}

	/// Forgets the kept copy (the module is being removed).
	public func removeDictionaryKeyCache(_ name: String) {
		try? FileManager.default.removeItem(atPath: keyCachePath(forModule: name))
		releaseDictionaryKeys(name)
	}
}

extension String {
	fileprivate init?(cString pointer: UnsafePointer<CChar>, encoding: String.Encoding) {
		self.init(data: Data(bytes: pointer, count: strlen(pointer)), encoding: encoding)
	}
}
