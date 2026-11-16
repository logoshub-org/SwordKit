// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd
// Rewritten from the About parts of SwordModule.mm (PocketSword, Nic Carter and CrossWire Bible Society)

import Foundation

extension SwordLibrary {

	/// The installed modules that declare a feature ("GreekDef", "HebrewDef", "GreekParse"), by name.
	public func modules(withFeature feature: String) -> [SwordModuleSummary] {
		allModules.filter { hasFeature(feature, module: $0.name) }
	}

	/// What a module offers to its About page, from wherever it is: installed here, or offered by a remote source.
	public struct ModuleFacts {
		public var info: SwordModuleInfo
		public var config: (String) -> String?
		public var has: (String) -> Bool
		public var locked: Bool

		package init(info: SwordModuleInfo, config: @escaping (String) -> String?, has: @escaping (String) -> Bool, locked: Bool) {
			self.info = info
			self.config = config
			self.has = has
			self.locked = locked
		}
	}

	package func facts(forModule name: String) -> ModuleFacts? {
		guard let info = info(forModule: name) else { return nil }
		return ModuleFacts(info: info, config: { self.configEntry($0, module: name) }, has: { self.hasFeature($0, module: name) }, locked: isLocked(info))
	}

	/// What the module declares, as the lines of its About page: the features and the title shown for each.
	package func featureTitles(forModule name: String) -> [String] {
		facts(forModule: name).map(Self.featureTitles) ?? []
	}

	package static func featureTitles(_ facts: ModuleFacts) -> [String] {
		let features: [(names: [String], title: String)] = [
			(["Strongs", "StrongsNumbers"], "AboutModuleContainsStrongsNumbers"),
			(["Morph"], "AboutModuleContainsMorphTags"),
			(["Footnotes"], "AboutModuleContainsFootnotes"),
			(["Headings"], "AboutModuleContainsHeadings"),
			(["RedLetterWords"], "AboutModuleContainsRedLetterWords"),
			(["GreekAccents"], "AboutModuleContainsGreekAccents"),
			(["Scripref"], "AboutModuleContainsScriptref"),
			(["Cantillation"], "AboutModuleContainsCantillation"),
			(["HebrewPoints"], "AboutModuleContainsHebrewPoints"),
			(["MorphSegmentation"], "AboutModuleContainsMorphSegmentation"),
			(["GreekDef"], "AboutModuleContainsGreekDef"),
			(["HebrewDef"], "AboutModuleContainsHebrewDef"),
			(["GreekParse"], "AboutModuleContainsGreekParse"),
			(["HebrewParse"], "AboutModuleContainsHebrewParse"),
			(["DailyDevotion"], "AboutModuleContainsDailyDevotion"),
			(["Images"], "AboutModuleContainsImages"),
		]
		return features.filter { entry in entry.names.contains(where: facts.has) }.map { SwordLibrary.localise($0.title) }
	}

	/// The module's facts for its About page, in the order the page shows them: `title` and `text`, `block` when the text starts a
	/// new line, and the conf's About text as written (RTF) under `rtf` for the page to turn into paragraphs.
	public func aboutFields(forModule name: String, currentVersion: String? = nil) -> [[String: Any]] {
		facts(forModule: name).map { Self.aboutFields($0, currentVersion: currentVersion) } ?? []
	}

	package static func aboutFields(_ facts: ModuleFacts, currentVersion: String? = nil) -> [[String: Any]] {
		let info = facts.info
		func title(_ key: String) -> String { SwordLibrary.localise(key) }
		var fields: [[String: Any]] = [
			["title": title("AboutModuleName"), "text": info.name],
			["title": title("AboutModuleDescription"), "text": info.description],
		]
		if facts.locked {
			fields.append(["title": title("AboutModuleLocked"), "text": ""])
		}
		if let lcsh = facts.config("LCSH") {
			fields.append(["title": title("AboutModuleLCSH"), "text": lcsh, "block": true])
		}
		fields.append(["title": title("AboutModuleType"), "text": info.type])
		fields.append(["title": title("AboutModuleLang"), "text": SwordLibrary.languageName(info.language ?? "en")])
		fields.append(["title": title("AboutModuleVersion"), "text": info.version ?? ""])
		if let currentVersion {
			fields.append(["title": title("AboutModuleCurrentVersion"), "text": currentVersion])
		}
		if let licence = facts.config("DistributionLicense") {
			fields.append(["title": title("AboutModuleLicence"), "text": licence])
		}
		let features = featureTitles(facts)
		if !features.isEmpty {
			fields.append(["title": title("AboutModuleFeaturesTitle"), "text": features.map { "\u{2022} " + $0 }.joined(separator: "\n"), "block": true])
		}
		fields.append(["title": title("AboutModuleAboutText"), "text": "", "rtf": facts.config("About") ?? "", "block": true])
		return fields
	}
}
