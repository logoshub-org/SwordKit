// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd

import XCTest
@testable import SwordProvider

/// A module's About page fields, from a conf given here: the copyright and licensing entries appear when the conf has them, in
/// their place, and a conf without them gives the fields it always did.
final class AboutFieldsTests: XCTestCase {

	private func fields(_ conf: [String: String]) -> [[String: Any]] {
		let info = SwordModuleInfo(name: "TEST", sourceType: "ThML", versification: "KJV", rightToLeft: false, unicode: true, osisQToTick: false,
		                           declaresGreekAccents: false, declaresHebrewPoints: false, declaresCantillation: false, verseKeyed: false,
		                           type: "Lexicons / Dictionaries", category: "Daily Devotional", description: "A test", language: "en",
		                           version: "1.3", cipherKey: nil)
		let facts = SwordLibrary.ModuleFacts(info: info, config: { conf[$0] }, has: { $0 == "DailyDevotion" && conf["Feature"] == $0 }, locked: false)
		return SwordLibrary.aboutFields(facts)
	}

	private func titles(_ fields: [[String: Any]]) -> [String] { fields.compactMap { $0["title"] as? String } }

	private func value(_ fields: [[String: Any]], _ title: String) -> String? {
		guard let field = fields.first(where: { $0["title"] as? String == title }) else { return nil }
		return field["rtf"] as? String ?? field["text"] as? String
	}

	func testAConfWithoutTheNewEntriesGivesTheFieldsItAlwaysDid() {
		XCTAssertEqual(titles(fields(["DistributionLicense": "Public Domain", "About": "x"])),
		               ["AboutModuleName", "AboutModuleDescription", "AboutModuleType", "AboutModuleLang", "AboutModuleVersion", "AboutModuleLicence",
		                "AboutModuleAboutText"])
	}

	func testTheCopyrightAndLicensingEntriesAppearInTheirPlace() {
		let all = fields([
			"LCSH": "Devotional calendars.", "SwordVersionDate": "2026-11-22", "DistributionLicense": "Copyrighted",
			"DistributionNotes": "Shared with permission.", "ShortCopyright": "© 2026 Everyday Scripture, Inc.",
			"CopyrightHolder": "Everyday Scripture, Inc.", "CopyrightDate": "2026", "CopyrightNotes": "Summaries only.",
			"CopyrightContactAddress": "https://everydayscripture.org/", "CopyrightContactEmail": "info@example.org",
			"TextSource": "BlueLetterBible.org", "Feature": "DailyDevotion", "About": "The plan.",
		])
		XCTAssertEqual(titles(all), ["AboutModuleName", "AboutModuleDescription", "AboutModuleLCSH", "AboutModuleType", "AboutModuleLang",
		                             "AboutModuleVersion", "AboutModuleVersionDate", "AboutModuleLicence", "AboutModuleDistributionNotes",
		                             "AboutModuleCopyright", "AboutModuleCopyrightHolder", "AboutModuleCopyrightDate", "AboutModuleCopyrightNotes",
		                             "AboutModuleCopyrightContact", "AboutModuleTextSource", "AboutModuleFeaturesTitle", "AboutModuleAboutText"])
		XCTAssertEqual(value(all, "AboutModuleCopyright"), "© 2026 Everyday Scripture, Inc.", "ShortCopyright when there is no Copyright")
		XCTAssertEqual(value(all, "AboutModuleCopyrightContact"), "https://everydayscripture.org/\\par info@example.org", "the contact's lines, one each")
		XCTAssertEqual(value(all, "AboutModuleVersionDate"), "2026-11-22")
	}

	func testCopyrightIsPreferredToShortCopyrightAndEmptyEntriesAreLeftOut() {
		let all = fields(["Copyright": "Copyright 2001 The Lockman Foundation", "ShortCopyright": "© Lockman", "TextSource": "  ", "CopyrightHolder": ""])
		XCTAssertEqual(value(all, "AboutModuleCopyright"), "Copyright 2001 The Lockman Foundation")
		XCTAssertNil(value(all, "AboutModuleTextSource"))
		XCTAssertNil(value(all, "AboutModuleCopyrightHolder"))
	}
}
