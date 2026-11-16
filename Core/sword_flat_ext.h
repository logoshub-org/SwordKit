// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd
//
// C layer over SWORD providing what CrossWire's flat API (flatapi.h) lacks, in the same style. Plain C, so Swift
// imports it without C++ interoperability and an Android build can call it through JNI. The handles are the flat API's
// (org_crosswire_sword_SWMgr_getModuleByName and the like). Strings are UTF-8, allocated with malloc, and freed by the
// matching swx_free_* call.

#ifndef SWORD_FLAT_EXT_H
#define SWORD_FLAT_EXT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef intptr_t SWXHANDLE;

/// One verse of a chapter. Verse 0 is the chapter's introduction (often empty).
struct swx_verse {
	int verse;
	char *text;
};

struct swx_chapter {
	char *osis_book;          // "Gen"
	int chapter;              // 1
	int count;                // the number of entries in `verses`
	struct swx_verse *verses;
};

/// Reads a whole chapter of a verse-keyed module in one call: the entries from the introduction to the last verse, raw (the
/// module's own markup) or, when `plain` is not zero, as SWORD's plain text. The module's position is left where it was.
/// `reference` is any chapter reference SWORD reads ("Genesis 1"). Returns 0 and fills `out`; or a non-zero code (nothing
/// to free): -1 for a bad argument, -2 for a module that is not verse-keyed.
int swx_read_chapter(SWXHANDLE module, const char *reference, int plain, struct swx_chapter *out);

void swx_free_chapter(struct swx_chapter *chapter);

/// Called while an index is built, with the percentage done and the `context` the caller gave.
typedef void (*swx_progress)(int percent, void *context);

/// Builds the module's CLucene search index (SWModule::createSearchFramework), which takes seconds to minutes. `progress` may
/// be null. Whether a module has an index is `org_crosswire_sword_SWModule_hasSearchFramework`; deleting one is
/// `org_crosswire_sword_SWModule_deleteSearchFramework`. Returns 0 on success; -1 for a bad argument; otherwise SWORD's code.
int swx_create_search_index(SWXHANDLE module, swx_progress progress, void *context);

/// One book of a versification system.
struct swx_book {
	char *name;                 // the interface language's name for the book ("Genèse")
	char *osis_name;            // "Gen"
	int new_testament;          // not zero for a book after the Old Testament
	int chapters;
	int *verses_per_chapter;    // `chapters` numbers, the first chapter first
};

struct swx_versification {
	int count;
	struct swx_book *books;
};

/// The books of a versification system in canonical order (SWORD's VersificationMgr). A name SWORD does not know gives
/// KJV's. Returns 0 and fills `out`; -1 for a bad argument; -3 when SWORD has no system to give.
int swx_versification_books(const char *system, struct swx_versification *out);

void swx_free_versification(struct swx_versification *versification);

/// The names of the versification systems SWORD knows ("KJV", "Vulg", "NRSV", ...): `count` strings, malloc'd; free with
/// swx_free_strings.
char **swx_versification_systems(int *count);

void swx_free_strings(char **strings, int count);

/// SWORD's own English name for a book given in the interface language ("Genèse" gives "Genesis"); the name itself when SWORD
/// does not know it. Free with free().
char *swx_english_book_name(const char *name);

/* ---- A module's facts, entries and passages --------------------------------------------------------------------------------- */

struct swx_module_info {
	char *source_type;               // the conf's SourceType ("OSIS", "ThML", "GBF", "TEI"), null when it has none
	char *versification;             // the conf's Versification, "KJV" when it has none
	int right_to_left;
	int unicode;
	int osis_q_to_tick;              // OSIS quotation marks are shown as the tick the module asks for: not "false"
	int verse_keyed;                 // a Bible or commentary (its key is a verse key)
	int declares_greek_accents;      // the module declares the Greek accents feature (Feature or a GlobalOptionFilter)
	int declares_hebrew_points;
	int declares_cantillation;
	char *type;                      // SWORD's type string: "Biblical Texts", "Commentaries", "Lexicons / Dictionaries", ...
	char *category;                  // the conf's Category ("Daily Devotional", "Glossaries", ...), null when it has none
	char *description;
	char *language;                  // the conf's Lang ("en"), null when it has none
	char *version;                   // the conf's Version, null when it has none
	char *cipher_key;                // the conf's CipherKey: null when the module is not encrypted, empty when it is locked
};

/// The facts about a module the readers need. Returns 0 and fills `out`; -1 for a bad handle.
int swx_module_info(SWXHANDLE module, struct swx_module_info *out);

void swx_free_module_info(struct swx_module_info *info);

/// Whether the module declares a feature ("GreekDef", "HebrewDef", "GreekParse", "StrongsNumbers", ...): a Feature entry, or a
/// GlobalOptionFilter naming a filter for it in any of SWORD's markups. 0 for a bad handle.
int swx_module_has_feature(SWXHANDLE module, const char *feature);

/// Installs every module found in a folder laid out as SWORD lays out a library (mods.d and modules, as in a raw module zip that has
/// been unpacked) into the library, as SWORD's own local install does. Returns the names installed (`count` strings, malloc'd; free
/// with swx_free_strings), or null for a bad argument.
char **swx_install_from_folder(SWXHANDLE library, const char *folder, int *count);

/// Points SWORD at a folder of locale files (locales.d) and chooses the locale for the reader's preferred languages, in order: the
/// first that SWORD has a file for, by its name or by the part before an underscore ("fr_CA" then "fr"). With none, SWORD's own
/// default stays. Process-wide.
void swx_init_locale(const char *locales_folder, const char **preferred, int count);

/// A value from the module's conf (`DistributionLicense`, `About`, `LCSH`, ...), UTF-8, malloc'd, freed with free(). Returns 0, or -1
/// for a bad argument, -3 when the conf has no such entry.
int swx_module_config_entry(SWXHANDLE module, const char *key, char **value);

/// One entry of a dictionary-like module (not a Bible or commentary), found by a key that is case-insensitive and tolerates
/// the zero padding Strong's modules use ("3588", "03588"). Returns 0 and the key as the module names it and the raw entry
/// (UTF-8, malloc'd, freed with free()); -1 for a bad argument, -2 for a verse-keyed module, -3 when there is no such entry.
int swx_read_entry(SWXHANDLE module, const char *key, char **found_key, char **raw);

/// The plain text (markup removed, under the display options set on the manager) of whatever `key` names in a verse-keyed or
/// other module, UTF-8, malloc'd. Returns 0, or -1 for a bad argument, -3 when the key is not in the module.
int swx_read_stripped(SWXHANDLE module, const char *key, char **text);

/// Every key of a dictionary-like module, in the module's order (`count` strings, UTF-8 as the module has them, malloc'd; free with
/// swx_free_strings). Null for a bad handle. A large dictionary takes a while: call it off the main thread.
char **swx_dictionary_keys(SWXHANDLE module, int *count);

/// The verses a passage names ("John 3:16-18, Rom 5"), each as SWORD writes it, read in the given versification system (null
/// or "" for the default). `count` strings, malloc'd; free with swx_free_strings.
char **swx_parse_passage(const char *reference, const char *versification, int *count);

/* ---- Searching ---------------------------------------------------------------------------------------------------------- */

enum {
	EB_SEARCH_ALL = 0,       // the whole module
	EB_SEARCH_OLD_TESTAMENT = 1,
	EB_SEARCH_NEW_TESTAMENT = 2,
	EB_SEARCH_BOOK = 3       // the book of `book_reference`
};

/// Whether the module has a CLucene index, by SWORD's own check (CLucene's IndexReader::indexExists).
int swx_has_search_index(SWXHANDLE module);

/// Searches a module: through its index when it has one (CLucene's query syntax: && || quotes lemma: *), otherwise with a
/// regular expression, case-insensitively. A range other than ALL applies to a verse-keyed module only, in `versification`
/// ("KJV" when null); BOOK takes the book of `book_reference` ("John 3"). Returns the hits' keys in canonical order, `count` of
/// them (UTF-8, malloc'd; free with swx_free_strings); `*used_index` says which kind of search ran. Null for a bad
/// handle.
char **swx_search(SWXHANDLE module, const char *term, int range, const char *book_reference, const char *versification,
                       int *count, int *used_index);

/* ---- Installing modules ------------------------------------------------------------------------------------------------
 * SWORD's install manager does the logic; the host does the HTTP. The host registers one fetch function (URLSession on iOS,
 * the platform's HTTP client on Android); SWORD asks it for every URL. The handles here are the flat API's InstallMgr
 * handles, so org_crosswire_sword_InstallMgr_* (refreshRemoteSource, getRemoteModInfoList, remoteInstallModule, ...) work on them.
 */

struct swx_http_request {
	const char *url;
	const char *user;          // "" for none
	const char *password;
	long timeout_ms;           // 0 for the default
	int allow_unverified;      // not zero to accept a certificate the system rejects
};

/// What the host may call while it fetches: report progress, and ask whether the user has cancelled. `transport` is passed back.
struct swx_http_hooks {
	void (*progress)(void *transport, unsigned long total, unsigned long completed);
	int (*cancelled)(void *transport);
	void *transport;
};

/// Fetches one URL completely into memory. Returns 0 and the body (malloc'd, freed by the caller of this function), or
/// -1 cancelled, -2 timed out, -3 access denied, -5 an HTTP error status, -10 anything else (SWORD's own codes).
typedef int (*swx_http_fetch)(void *context, const struct swx_http_request *request, const struct swx_http_hooks *hooks,
                             unsigned char **body, unsigned long *length);

/// Registers the host's fetch function for the whole process. Null removes it.
void swx_set_http_fetch(swx_http_fetch fetch, void *context);

/// Called with SWORD's message ("update", or a stage's name) and the bytes in all and so far.
typedef void (*swx_status_callback)(const char *message, unsigned long total, unsigned long completed, void *context);

/// Opens the install manager for the folder `base_dir` (its InstallMgr.conf lives there). The default sources are written when
/// the file is missing or when `reset_sources` is not zero; each package-preference entry gets a uid of its own. FTP is not
/// available. Returns the handle, or 0.
SWXHANDLE swx_install_new(const char *base_dir, int reset_sources, swx_status_callback status, void *context);

/// Frees the install manager; the handle must not be used afterwards.
void swx_install_delete(SWXHANDLE install);

/// One source of modules (a line of InstallMgr.conf).
struct swx_source {
	char *type;                // "HTTPS", "HTTP" or "FTP"
	char *caption;
	char *source;              // the host
	char *directory;
	char *uid;
	int package_preference;    // not zero when packages/<module>.zip is tried first
};

/// The sources in the order the file has them. Free with swx_free_sources.
struct swx_source *swx_install_sources(SWXHANDLE install, int *count);

void swx_free_sources(struct swx_source *sources, int count);

/// Adds a source (the `package_preference` entry too, when set) and reloads the install manager.
int swx_install_add_source(SWXHANDLE install, const struct swx_source *source);

/// Removes the source with this caption, keeping the others (and their package preferences), and reloads.
int swx_install_remove_source(SWXHANDLE install, const char *caption);

#ifdef __cplusplus
}
#endif

#endif
