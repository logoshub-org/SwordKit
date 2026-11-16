// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd
//
// The Swift side of the C layer over SWORD (plan D134): a library of installed modules, and the reads the readers make of it.
// It replaced EBSwordRawSource (Objective-C) and, as the other callers move, replaces the Objective-C SwordManager and SwordModule.

import Foundation
import CSwordCore

/// A module's facts, as the readers need them.
public struct SwordModuleInfo {
	public var name: String
	public var sourceType: String?
	public var versification: String
	public var rightToLeft: Bool
	public var unicode: Bool
	public var osisQToTick: Bool
	public var declaresGreekAccents: Bool
	public var declaresHebrewPoints: Bool
	public var declaresCantillation: Bool
	/// A Bible or commentary: its entries are keyed by verse.
	public var verseKeyed: Bool
	/// SWORD's type string ("Biblical Texts", "Commentaries", "Lexicons / Dictionaries", "Generic Books").
	public var type: String
	/// The conf's Category ("Daily Devotional", "Glossaries", ...), nil when it has none.
	public var category: String?
	public var description: String
	public var language: String?
	public var version: String?
	/// The conf's CipherKey: nil when the module is not encrypted, empty when it is locked.
	public var cipherKey: String?

	package init(name: String, sourceType: String?, versification: String, rightToLeft: Bool, unicode: Bool, osisQToTick: Bool, declaresGreekAccents: Bool, declaresHebrewPoints: Bool, declaresCantillation: Bool, verseKeyed: Bool, type: String, category: String?, description: String, language: String?, version: String?, cipherKey: String?) {
		self.name = name
		self.sourceType = sourceType
		self.versification = versification
		self.rightToLeft = rightToLeft
		self.unicode = unicode
		self.osisQToTick = osisQToTick
		self.declaresGreekAccents = declaresGreekAccents
		self.declaresHebrewPoints = declaresHebrewPoints
		self.declaresCantillation = declaresCantillation
		self.verseKeyed = verseKeyed
		self.type = type
		self.category = category
		self.description = description
		self.language = language
		self.version = version
		self.cipherKey = cipherKey
	}
}

/// The kinds of module the reader's lists show.
public enum SwordModuleKind {
	case bible, commentary, dictionary, devotional

	/// SWORD's type string for the kind (a devotional is a dictionary with a Category of its own).
	public var type: String {
		switch self {
		case .bible: return "Biblical Texts"
		case .commentary: return "Commentaries"
		case .dictionary, .devotional: return "Lexicons / Dictionaries"
		}
	}
}

/// A module as a list shows it.
public struct SwordModuleSummary: Equatable {
	public var name: String
	/// The module's description, or its name when it has none: the text a row shows.
	public var title: String
	public var type: String
	public var category: String?
	public var language: String?
	public var version: String?
	/// Encrypted and not yet unlocked.
	public var locked: Bool

	package init(name: String, title: String, type: String, category: String?, language: String?, version: String?, locked: Bool) {
		self.name = name
		self.title = title
		self.type = type
		self.category = category
		self.language = language
		self.version = version
		self.locked = locked
	}
}

/// One entry of a chapter: verse 0 is the chapter's introduction.
public struct SwordRawEntry: Equatable {
	public var verse: Int
	public var text: String

	package init(verse: Int, text: String) {
		self.verse = verse
		self.text = text
	}
}

public struct SwordRawChapter: Equatable {
	public var book: String
	public var chapter: Int
	public var entries: [SwordRawEntry]

	package init(book: String, chapter: Int, entries: [SwordRawEntry]) {
		self.book = book
		self.chapter = chapter
		self.entries = entries
	}
}

/// An entry of a dictionary-like module, or a passage's verse: a key and its text.
public struct SwordEntry: Equatable {
	public var key: String
	public var raw: String

	package init(key: String, raw: String) {
		self.key = key
		self.raw = raw
	}
}

/// The switches that change what SWORD's plain text contains.
public struct SwordDisplayOptions: Equatable {
	package var crossReferences = false
	package var strongs = false
	package var morphology = false
	package var headings = false
	package var footnotes = false
	package var redLetters = false
	package var greekAccents = false
	package var hebrewVowelPoints = false
	package var hebrewCantillation = false

	public init(crossReferences: Bool = false, strongs: Bool = false, morphology: Bool = false, headings: Bool = false,
	            footnotes: Bool = false, redLetters: Bool = false, greekAccents: Bool = false, hebrewVowelPoints: Bool = false,
	            hebrewCantillation: Bool = false) {
		self.crossReferences = crossReferences
		self.strongs = strongs
		self.morphology = morphology
		self.headings = headings
		self.footnotes = footnotes
		self.redLetters = redLetters
		self.greekAccents = greekAccents
		self.hebrewVowelPoints = hebrewVowelPoints
		self.hebrewCantillation = hebrewCantillation
	}
}

/// The folder of installed modules, open through SWORD. One shared library serves the app; it is opened again when modules are
/// installed or removed. SWORD keeps state in its manager and modules (the current key, the display options), so every read
/// goes through the library's lock.
public final class SwordLibrary {

	/// Posted when modules were installed or removed by anyone: a library that observes changes opens its folder again.
	public static let modulesChangedNotification = Notification.Name("NotificationModulesChanged")

	/// The words of a module's About page (and the feature names) in the reader's language: the host supplies the lookup.
	nonisolated(unsafe) public static var localise: (String) -> String = { $0 }

	/// The name of a language from its code, in the reader's language: the host supplies the table.
	nonisolated(unsafe) public static var languageName: (String) -> String = { $0 }

	/// The display switches SWORD is given (they change what plain text contains): the host reads them from its own preferences.
	public var displayOptions: () -> SwordDisplayOptions = { SwordDisplayOptions() }

	package let path: String
	private var manager: SWXHANDLE = 0
	package let lock = NSRecursiveLock()
	private var observer: NSObjectProtocol?
	private let defaults: UserDefaults
	/// The keys of the dictionaries read this run, by module name (`SwordDictionaryKeys.swift`); guarded by `lock`.
	package var dictionaryKeysInMemory: [String: [String]] = [:]
	/// Where a dictionary's keys are kept between runs.
	package var keyCacheFolder = (NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as NSString) as String

	public init(path: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0], defaults: UserDefaults = .standard,
	     observesChanges: Bool = true) {
		self.path = path
		self.defaults = defaults
		manager = SWXHANDLE(org_crosswire_sword_SWMgr_newWithPath(path))
		openedAt = modifiedAt()
		applyStoredCipherKeys()
		if observesChanges {
			observer = NotificationCenter.default.addObserver(forName: Self.modulesChangedNotification, object: nil, queue: nil) { [weak self] _ in
				self?.reload()
			}
		}
	}

	deinit {
		if let observer { NotificationCenter.default.removeObserver(observer) }
		if manager != 0 { org_crosswire_sword_SWMgr_delete(manager) }
	}

	/// Opens the folder again: modules were installed or removed.
	public func reload() {
		lock.lock()
		defer { lock.unlock() }
		if manager != 0 { org_crosswire_sword_SWMgr_delete(manager) }
		manager = SWXHANDLE(org_crosswire_sword_SWMgr_newWithPath(path))
		openedAt = modifiedAt()
		applyStoredCipherKeys()
	}

	/// When the library's `mods.d` was last changed, as it was when the library was opened: modules installed or removed by
	/// anyone else (the Objective-C install path, a file copied in) change it.
	private var openedAt: Date?

	private func modifiedAt() -> Date? {
		(try? FileManager.default.attributesOfItem(atPath: path + "/mods.d"))?[.modificationDate] as? Date
	}

	/// Runs `body` with the library locked and a module's handle, or nil when there is no such module. A module that is not
	/// there is looked for again if the folder has changed since the library was opened.
	package func withModule<T>(_ name: String, _ body: (SWXHANDLE) -> T?) -> T? {
		lock.lock()
		defer { lock.unlock() }
		var module = SWXHANDLE(org_crosswire_sword_SWMgr_getModuleByName(manager, name))
		if module == 0, modifiedAt() != openedAt {
			reload()
			module = SWXHANDLE(org_crosswire_sword_SWMgr_getModuleByName(manager, name))
		}
		guard module != 0 else { return nil }
		return body(module)
	}

	/// Runs `body` with the library locked and its manager's handle (for the install manager, which reads and writes the folder).
	package func withManager<T>(_ body: (SWXHANDLE) -> T) -> T {
		lock.lock()
		defer { lock.unlock() }
		return body(manager)
	}

	// MARK: The modules

	public var moduleNames: [String] {
		lock.lock()
		defer { lock.unlock() }
		if modifiedAt() != openedAt { reload() }
		var names: [String] = []
		var info = org_crosswire_sword_SWMgr_getModInfoList(manager)
		while let entry = info, let name = entry.pointee.name {
			names.append(String(cString: name))
			info = entry + 1
		}
		return names
	}

	public func info(forModule name: String) -> SwordModuleInfo? {
		withModule(name) { Self.info(handle: $0, name: name) }
	}

	/// The facts about a module from its handle (an installed module's, or one a remote source offers).
	public static func info(handle module: SWXHANDLE, name: String) -> SwordModuleInfo? {
		var info = swx_module_info()
		guard swx_module_info(module, &info) == 0 else { return nil }
		defer { swx_free_module_info(&info) }
		return SwordModuleInfo(
			name: name, sourceType: info.source_type.map { String(cString: $0) }, versification: String(cString: info.versification),
			rightToLeft: info.right_to_left != 0, unicode: info.unicode != 0, osisQToTick: info.osis_q_to_tick != 0,
			declaresGreekAccents: info.declares_greek_accents != 0, declaresHebrewPoints: info.declares_hebrew_points != 0,
			declaresCantillation: info.declares_cantillation != 0, verseKeyed: info.verse_keyed != 0,
			type: String(cString: info.type), category: info.category.map { String(cString: $0) }, description: String(cString: info.description),
			language: info.language.map { String(cString: $0) }, version: info.version.map { String(cString: $0) },
			cipherKey: info.cipher_key.map { String(cString: $0) })
	}

	/// A value from a module's conf, by its handle.
	package static func configEntry(_ key: String, handle module: SWXHANDLE) -> String? {
		var value: UnsafeMutablePointer<CChar>?
		guard swx_module_config_entry(module, key, &value) == 0, let value else { return nil }
		defer { free(value) }
		return String(cString: value)
	}

	/// Whether the module declares a feature ("GreekDef", "HebrewDef", "GreekParse", "StrongsNumbers", ...).
	public func hasFeature(_ feature: String, module name: String) -> Bool {
		withModule(name) { swx_module_has_feature($0, feature) != 0 } ?? false
	}

	/// A value from the module's conf (`DistributionLicense`, `About`, `LCSH`, ...), nil when the conf has none.
	package func configEntry(_ key: String, module name: String) -> String? {
		withModule(name) { Self.configEntry(key, handle: $0) }
	}

	// MARK: Installing from a folder

	/// Installs the modules in an unpacked folder of raw modules (mods.d and modules) into the library. The names installed.
	@discardableResult
	public func installModules(fromFolder folder: String) -> [String] {
		let installed = withManager { manager -> [String] in
			var count: Int32 = 0
			guard let list = swx_install_from_folder(manager, folder, &count) else { return [] }
			defer { swx_free_strings(list, count) }
			return (0..<Int(count)).compactMap { list[$0].map { String(cString: $0) } }
		}
		reload()
		return installed
	}

	// MARK: Lists

	/// The modules of a kind, by name. A dictionary here is one with no category of its own (not a glossary, devotional, essay or
	/// questionable one); the others are listed under their own kinds or not at all.
	public func modules(of kind: SwordModuleKind) -> [SwordModuleSummary] {
		moduleNames.compactMap { name -> SwordModuleSummary? in
			guard let info = info(forModule: name), info.type == kind.type else { return nil }
			switch kind {
			case .dictionary: if let category = info.category, Self.otherCategories.contains(category) { return nil }
			case .devotional: if info.category != "Daily Devotional" { return nil }
			case .bible, .commentary: break
			}
			return summary(of: info)
		}.sorted { $0.name < $1.name }
	}

	/// Every module, by name.
	public var allModules: [SwordModuleSummary] {
		moduleNames.compactMap { name in info(forModule: name).map { summary(of: $0) } }.sorted { $0.name < $1.name }
	}

	private static let otherCategories: Set<String> = ["Glossaries", "Daily Devotional", "Essays", "Cults / Unorthodox / Questionable Material"]

	private func summary(of info: SwordModuleInfo) -> SwordModuleSummary {
		SwordModuleSummary(name: info.name, title: info.description.isEmpty ? info.name : info.description, type: info.type, category: info.category,
		                     language: info.language, version: info.version, locked: isLocked(info))
	}

	// MARK: Searching

	/// Where a search looks.
	public enum SearchRange: Equatable {
		case all, oldTestament, newTestament
		/// The book of a reference ("John 3" searches John).
		case book(String)
	}

	public struct SearchResult: Equatable {
		/// The hits, as SWORD writes them ("John 3:16"), in canonical order.
		public var keys: [String]
		/// Whether the module's CLucene index answered (otherwise a regular expression over the whole text did).
		public var usedIndex: Bool

		package init(keys: [String], usedIndex: Bool) {
			self.keys = keys
			self.usedIndex = usedIndex
		}
	}

	public func hasSearchIndex(_ name: String) -> Bool {
		withModule(name) { swx_has_search_index($0) != 0 } ?? false
	}

	/// Searches a module. The range applies to a Bible or commentary, in `versification` (the module's own when nil).
	public func search(module name: String, term: String, range: SearchRange = .all, versification: String? = nil) -> SearchResult? {
		let system = versification ?? info(forModule: name)?.versification
		let (kind, book): (Int32, String?) = {
			switch range {
			case .all: return (Int32(EB_SEARCH_ALL), nil)
			case .oldTestament: return (Int32(EB_SEARCH_OLD_TESTAMENT), nil)
			case .newTestament: return (Int32(EB_SEARCH_NEW_TESTAMENT), nil)
			case .book(let reference): return (Int32(EB_SEARCH_BOOK), reference)
			}
		}()
		return withModule(name) { module in
			var count: Int32 = 0
			var usedIndex: Int32 = 0
			guard let hits = swx_search(module, term, kind, book, system, &count, &usedIndex) else { return nil }
			defer { swx_free_strings(hits, count) }
			return SearchResult(keys: (0..<Int(count)).compactMap { hits[$0].map { String(cString: $0) } }, usedIndex: usedIndex != 0)
		}
	}

	private final class ProgressBox {
		package let report: (Int) -> Void
		package init(_ report: @escaping (Int) -> Void) { self.report = report }
	}

	/// Builds the module's search index, which takes seconds to minutes (about 13 s for the KJV on a simulator); `progress` is
	/// told the percentage done. False when SWORD reports an error.
	@discardableResult
	public func createSearchIndex(_ name: String, progress: ((Int) -> Void)? = nil) -> Bool {
		withModule(name) { module -> Bool? in
			let box = progress.map { ProgressBox($0) }
			let context = box.map { Unmanaged.passUnretained($0).toOpaque() }
			let result = swx_create_search_index(module, box == nil ? nil : { percent, context in
				Unmanaged<ProgressBox>.fromOpaque(context!).takeUnretainedValue().report(Int(percent))
			}, context)
			withExtendedLifetime(box) {}
			return result == 0
		} ?? false
	}

	public func deleteSearchIndex(_ name: String) {
		_ = withModule(name) { module -> Bool? in
			org_crosswire_sword_SWModule_deleteSearchFramework(module)
			return true
		}
	}

	// MARK: Locked modules

	private static let cipherKeysKey = "DefaultsModuleCipherKeysKey"

	private var storedCipherKeys: [String: String] {
		defaults.dictionary(forKey: Self.cipherKeysKey) as? [String: String] ?? [:]
	}

	/// Encrypted, with an empty key in its conf and none entered by the reader.
	public func isLocked(_ info: SwordModuleInfo) -> Bool {
		(info.cipherKey ?? "").isEmpty && info.cipherKey != nil && storedCipherKeys[info.name] == nil
	}

	/// Whether the module is encrypted and not yet unlocked.
	public func isLocked(module name: String) -> Bool { info(forModule: name).map(isLocked) ?? false }

	/// Whether the module is encrypted (its conf has a CipherKey entry, or the reader has entered one).
	public func isEncrypted(_ name: String) -> Bool {
		guard let info = info(forModule: name) else { return false }
		return info.cipherKey != nil || storedCipherKeys[name] != nil
	}

	/// Keeps the key the reader entered and gives it to SWORD; a nil key forgets it. False for a module that is not encrypted.
	@discardableResult
	public func unlock(moduleNamed name: String, key: String?) -> Bool {
		guard isEncrypted(name) else { return false }
		var keys = storedCipherKeys
		if let key { keys[name] = key } else { keys.removeValue(forKey: name) }
		defaults.set(keys, forKey: Self.cipherKeysKey)
		lock.lock()
		org_crosswire_sword_SWMgr_setCipherKey(manager, name, key ?? "")
		lock.unlock()
		return true
	}

	/// Gives SWORD the keys the reader has entered, when the library is opened.
	private func applyStoredCipherKeys() {
		for (name, key) in storedCipherKeys { org_crosswire_sword_SWMgr_setCipherKey(manager, name, key) }
	}

	// MARK: Display options

	/// The display switches, as SWORD's global options on this library, which change what plain text contains.
	public func applyDisplayPreferences() {
		lock.lock()
		defer { lock.unlock() }
		let options = displayOptions()
		func set(_ option: String, _ on: Bool) { org_crosswire_sword_SWMgr_setGlobalOption(manager, option, on ? "On" : "Off") }
		set("Cross-references", options.crossReferences)
		set("Strong's Numbers", options.strongs)
		set("Morphological Tags", options.morphology)
		set("Headings", options.headings)
		set("Footnotes", options.footnotes)
		set("Words of Christ in Red", options.redLetters)
		set("Greek Accents", options.greekAccents)
		set("Hebrew Vowel Points", options.hebrewVowelPoints)
		set("Hebrew Cantillation", options.hebrewCantillation)
		// constants
		org_crosswire_sword_SWMgr_setGlobalOption(manager, "Textual Variants", "Primary Reading")
		set("Glosses", true)
	}

	// MARK: Reads

	/// A whole chapter, in the module's own markup.
	public func rawChapter(forModule name: String, reference: String) -> SwordRawChapter? {
		chapter(forModule: name, reference: reference, plain: false)
	}

	/// A whole chapter as SWORD's plain text, under the reader's display switches.
	public func plainChapter(forModule name: String, reference: String) -> SwordRawChapter? {
		applyDisplayPreferences()
		return chapter(forModule: name, reference: reference, plain: true)
	}

	private func chapter(forModule name: String, reference: String, plain: Bool) -> SwordRawChapter? {
		withModule(name) { module in
			var chapter = swx_chapter()
			guard swx_read_chapter(module, reference, plain ? 1 : 0, &chapter) == 0 else { return nil }
			defer { swx_free_chapter(&chapter) }
			let verses = UnsafeBufferPointer(start: chapter.verses, count: Int(chapter.count))
			return SwordRawChapter(book: String(cString: chapter.osis_book), chapter: Int(chapter.chapter),
			                         entries: verses.map { SwordRawEntry(verse: Int($0.verse), text: String(cString: $0.text)) })
		}
	}

	/// An entry of a dictionary-like module, nil for a Bible or commentary, or for a key it does not have.
	public func entry(forModule name: String, key: String) -> SwordEntry? {
		withModule(name) { module in
			var found: UnsafeMutablePointer<CChar>?
			var raw: UnsafeMutablePointer<CChar>?
			guard swx_read_entry(module, key, &found, &raw) == 0, let found, let raw else { return nil }
			defer { free(found); free(raw) }
			return SwordEntry(key: String(cString: found), raw: String(cString: raw))
		}
	}

	/// The plain text of each reference in `reference` (separated by white space), in the order given; those the module has
	/// nothing for are left out. Nil when there is no such module.
	public func passage(forModule name: String, reference: String) -> [SwordEntry]? {
		withModule(name) { module -> [SwordEntry]? in
			var result: [SwordEntry] = []
			for ref in reference.components(separatedBy: .whitespacesAndNewlines) where !ref.isEmpty {
				var text: UnsafeMutablePointer<CChar>?
				guard swx_read_stripped(module, ref, &text) == 0, let text else { continue }
				defer { free(text) }
				let stripped = String(cString: text)
				if !stripped.isEmpty { result.append(SwordEntry(key: Self.referenceString(ref), raw: stripped)) }
			}
			return result
		}
	}

	/// The plain text of one verse (or other key) as SWORD writes the key ("John 3:16"), under the display options; nil when the module
	/// has none.
	public func strippedText(forModule name: String, key: String) -> String? {
		withModule(name) { module -> String? in
			var text: UnsafeMutablePointer<CChar>?
			guard swx_read_stripped(module, key, &text) == 0, let text else { return nil }
			defer { free(text) }
			return String(cString: text)
		} ?? nil
	}

	/// The verses a passage names, one reference each ("Genesis 4:25", "Genesis 4:26"), read in a versification system.
	public static func verseReferences(forPassage reference: String, versification: String) -> [String] {
		var count: Int32 = 0
		guard let list = swx_parse_passage(reference, versification, &count) else { return [] }
		defer { swx_free_strings(list, count) }
		return (0..<Int(count)).compactMap { list[$0].map { referenceString(String(cString: $0)) } }
	}

	/// A reference with SWORD's Roman numerals as digits ("III John 1:1" is "3 John 1:1").
	public static func referenceString(_ reference: String) -> String {
		reference.replacingOccurrences(of: "III ", with: "3 ").replacingOccurrences(of: "II ", with: "2 ")
			.replacingOccurrences(of: "I ", with: "1 ").replacingOccurrences(of: " of John ", with: " ")
	}
}
