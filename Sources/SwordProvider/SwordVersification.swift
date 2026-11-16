// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd
// Rewritten from EBSwordVersification.mm and SwordBook.mm (PocketSword, Nic Carter and CrossWire Bible Society)

import Foundation
import CSwordCore

/// One book of a SWORD versification system.
public struct SwordVersificationBook: Equatable {
	/// As SWORD names it in the interface language ("III John", "Genèse").
	public var name: String
	/// "Gen".
	public var osis: String
	/// The verses in each chapter, first chapter first.
	public var versesPerChapter: [Int]
	public var newTestament: Bool

	public init(name: String, osis: String, versesPerChapter: [Int], newTestament: Bool) {
		self.name = name
		self.osis = osis
		self.versesPerChapter = versesPerChapter
		self.newTestament = newTestament
	}

	public var chapters: Int { versesPerChapter.count }

	/// The name as the app shows it: Roman numerals as digits, and no "of John" ("III John" is "3 John").
	public var displayName: String {
		name.replacingOccurrences(of: "III ", with: "3 ").replacingOccurrences(of: "II ", with: "2 ")
			.replacingOccurrences(of: "I ", with: "1 ").replacingOccurrences(of: " of John", with: "")
	}
}

extension SwordLibrary {

	/// The books of a system in canonical order; an unknown system gives KJV's.
	public static func versificationBooks(_ system: String) -> [SwordVersificationBook] {
		var result = swx_versification()
		guard swx_versification_books(system, &result) == 0 else { return [] }
		defer { swx_free_versification(&result) }
		return (0..<Int(result.count)).map { index in
			let book = result.books[index]
			return SwordVersificationBook(name: String(cString: book.name), osis: String(cString: book.osis_name),
			                           versesPerChapter: (0..<Int(book.chapters)).map { Int(book.verses_per_chapter[$0]) },
			                           newTestament: book.new_testament != 0)
		}
	}

	/// SWORD's English name for a book given in the interface language; the name itself when SWORD does not know it.
	public static func englishBookName(_ name: String) -> String {
		guard let english = swx_english_book_name(name) else { return name }
		defer { free(english) }
		return String(cString: english)
	}
}
