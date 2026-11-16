// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd
//
// Our own C layer over SWORD (plan D134). This file includes CrossWire's flat API implementation, so that our functions use
// its handle classes (HandleSWMgr, HandleSWModule, HandleInstMgr) and no SWORD file is copied into ours or edited. If an
// engine update reshapes those classes, this file fails to compile, and the fix is here.

#include "../Vendor/sword/bindings/flatapi.cpp"

#include "sword_flat_ext.h"

#include <regex.h>
#include <versificationmgr.h>
#include <localemgr.h>

#include <cstdlib>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <list>
#include <vector>

namespace {

// SWORD keeps no lock of its own and a module's key is shared state: one lock per module, held for a whole chapter.
std::recursive_mutex &lockFor(sword::SWModule *module) {
	static std::mutex registryLock;
	static std::map<sword::SWModule *, std::unique_ptr<std::recursive_mutex>> locks;
	std::lock_guard<std::mutex> guard(registryLock);
	std::unique_ptr<std::recursive_mutex> &entry = locks[module];
	if(!entry) {
		entry.reset(new std::recursive_mutex());
	}
	return *entry;
}

bool isValidUTF8(const unsigned char *s) {
	while(*s) {
		int extra = 0;
		if(*s < 0x80) extra = 0;
		else if((*s & 0xE0) == 0xC0 && *s >= 0xC2) extra = 1;
		else if((*s & 0xF0) == 0xE0) extra = 2;
		else if((*s & 0xF8) == 0xF0 && *s <= 0xF4) extra = 3;
		else return false;
		++s;
		for(int i = 0; i < extra; ++i, ++s) {
			if((*s & 0xC0) != 0x80) return false;
		}
	}
	return true;
}

// Windows-1252 to UTF-8: the bytes 0x80-0x9F differ from Latin-1; the five it leaves undefined map to themselves.
void appendCodePoint(std::string &out, unsigned int c) {
	if(c < 0x80) {
		out += (char)c;
	} else if(c < 0x800) {
		out += (char)(0xC0 | (c >> 6));
		out += (char)(0x80 | (c & 0x3F));
	} else {
		out += (char)(0xE0 | (c >> 12));
		out += (char)(0x80 | ((c >> 6) & 0x3F));
		out += (char)(0x80 | (c & 0x3F));
	}
}

std::string windows1252ToUTF8(const char *bytes) {
	static const unsigned int high[32] = {
		0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
		0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178 };
	std::string out;
	for(const unsigned char *p = (const unsigned char *)bytes; *p; ++p) {
		appendCodePoint(out, (*p >= 0x80 && *p < 0xA0) ? high[*p - 0x80] : *p);
	}
	return out;
}

// A Unicode module's bytes are UTF-8; bytes that are not valid in the declared encoding are read as Windows-1252 so that the
// text stays readable.
std::string decode(const char *raw, bool unicode) {
	if(!raw) {
		return "";
	}
	if(unicode && isValidUTF8((const unsigned char *)raw)) {
		return raw;
	}
	return windows1252ToUTF8(raw);
}

// "Genesis 1:3" -> "Genesis 1"
std::string chapterOf(const char *keyText) {
	std::string text = keyText ? keyText : "";
	return text.substr(0, text.find(':'));
}

char *copyString(const std::string &s) {
	char *copy = (char *)malloc(s.size() + 1);
	memcpy(copy, s.c_str(), s.size() + 1);
	return copy;
}

} // namespace

extern "C" int swx_read_chapter(SWXHANDLE handle, const char *reference, int plain, struct swx_chapter *out) {
	if(!out) {
		return -1;
	}
	memset(out, 0, sizeof(*out));
	HandleSWModule *hmod = (HandleSWModule *)handle;
	if(!hmod || !hmod->mod || !reference) {
		return -1;
	}
	sword::SWModule *module = hmod->mod;
	std::lock_guard<std::recursive_mutex> guard(lockFor(module));

	sword::VerseKey *key = SWDYNAMIC_CAST(VerseKey, module->getKey());
	if(!key) {
		return -2;
	}

	// The reader must not move anyone else's place: put the key and its introductions flag back when done.
	const std::string savedText = key->getText();
	const bool savedIntros = key->isIntros();

	key->setIntros(true);
	key->setText(reference);
	const std::string osisBook = key->getOSISBookName();
	const int chapterNumber = key->getChapter();
	key->setVerse(0);

	module->stripText();   // forces the key to be processed
	const std::string chapterName = chapterOf(module->getKeyText());
	const bool unicode = module->isUnicode();

	std::vector<std::string> texts;
	int verse = 0;
	std::string current;
	do {
		const char *raw = 0;
		sword::SWBuf strippedText;   // stripText() returns a temporary: keep it alive while the bytes are copied
		if(plain) {
			strippedText = module->stripText();
			raw = strippedText.c_str();
		} else {
			raw = module->getRawEntry();
		}
		texts.push_back(decode(raw, unicode));

		(*module->getKey())++;
		module->stripText();
		current = chapterOf(module->getKeyText());
		++verse;
	} while(current == chapterName && module->getKey()->popError() != KEYERR_OUTOFBOUNDS);

	key->setIntros(savedIntros);
	key->setText(savedText.c_str());
	module->stripText();

	out->osis_book = copyString(osisBook);
	out->chapter = chapterNumber;
	out->count = (int)texts.size();
	out->verses = (struct swx_verse *)calloc(texts.size(), sizeof(struct swx_verse));
	for(size_t i = 0; i < texts.size(); ++i) {
		out->verses[i].verse = (int)i;
		out->verses[i].text = copyString(texts[i]);
	}
	return 0;
}

extern "C" void swx_free_chapter(struct swx_chapter *chapter) {
	if(!chapter) {
		return;
	}
	for(int i = 0; i < chapter->count; ++i) {
		free(chapter->verses[i].text);
	}
	free(chapter->verses);
	free(chapter->osis_book);
	memset(chapter, 0, sizeof(*chapter));
}

namespace {

struct IndexProgress {
	swx_progress callback;
	void *context;
};

void indexPercent(char percent, void *userData) {
	IndexProgress *progress = (IndexProgress *)userData;
	if(progress && progress->callback) {
		progress->callback((int)percent, progress->context);
	}
}

} // namespace

extern "C" int swx_create_search_index(SWXHANDLE handle, swx_progress progress, void *context) {
	HandleSWModule *hmod = (HandleSWModule *)handle;
	if(!hmod || !hmod->mod) {
		return -1;
	}
	sword::SWModule *module = hmod->mod;
	std::lock_guard<std::recursive_mutex> guard(lockFor(module));
	IndexProgress state = { progress, context };
	return (int)module->createSearchFramework(&indexPercent, &state);
}

extern "C" int swx_versification_books(const char *systemName, struct swx_versification *out) {
	if(!out || !systemName) {
		return -1;
	}
	memset(out, 0, sizeof(*out));
	sword::VersificationMgr *manager = sword::VersificationMgr::getSystemVersificationMgr();
	const sword::VersificationMgr::System *system = manager->getVersificationSystem(systemName);
	if(!system) {
		system = manager->getVersificationSystem("KJV");
	}
	if(!system) {
		return -3;
	}
	sword::LocaleMgr *locales = sword::LocaleMgr::getSystemLocaleMgr();
	const int oldTestamentBooks = system->getBMAX()[0];   // getBMAX()[0] is the number of Old Testament books
	const int bookCount = system->getBookCount();
	out->count = bookCount;
	out->books = (struct swx_book *)calloc(bookCount, sizeof(struct swx_book));
	for(int i = 0; i < bookCount; ++i) {
		const sword::VersificationMgr::Book *book = system->getBook(i);
		struct swx_book &entry = out->books[i];
		entry.name = copyString(decode(locales->translate(book->getLongName()), true));
		entry.osis_name = copyString(book->getOSISName());
		entry.new_testament = (i >= oldTestamentBooks) ? 1 : 0;
		entry.chapters = book->getChapterMax();
		entry.verses_per_chapter = (int *)calloc(entry.chapters > 0 ? entry.chapters : 1, sizeof(int));
		for(int chapter = 1; chapter <= entry.chapters; ++chapter) {
			entry.verses_per_chapter[chapter - 1] = book->getVerseMax(chapter);
		}
	}
	return 0;
}

extern "C" void swx_free_versification(struct swx_versification *versification) {
	if(!versification) {
		return;
	}
	for(int i = 0; i < versification->count; ++i) {
		free(versification->books[i].name);
		free(versification->books[i].osis_name);
		free(versification->books[i].verses_per_chapter);
	}
	free(versification->books);
	memset(versification, 0, sizeof(*versification));
}

extern "C" char **swx_versification_systems(int *count) {
	if(!count) {
		return 0;
	}
	const sword::StringList systems = sword::VersificationMgr::getSystemVersificationMgr()->getVersificationSystems();
	*count = (int)systems.size();
	char **names = (char **)calloc(systems.size() > 0 ? systems.size() : 1, sizeof(char *));
	int i = 0;
	for(sword::StringList::const_iterator it = systems.begin(); it != systems.end(); ++it) {
		names[i++] = copyString(it->c_str());
	}
	return names;
}

extern "C" void swx_free_strings(char **strings, int count) {
	if(!strings) {
		return;
	}
	for(int i = 0; i < count; ++i) {
		free(strings[i]);
	}
	free(strings);
}

extern "C" char *swx_english_book_name(const char *name) {
	if(!name) {
		return 0;
	}
	sword::LocaleMgr *locales = sword::LocaleMgr::getSystemLocaleMgr();
	const char *english = locales->translate(name, "en");
	return copyString(english ? english : name);
}

// ---- Installing modules ----------------------------------------------------------------------------------------------------

namespace {

swx_http_fetch gFetch = 0;
void *gFetchContext = 0;

// SWORD's transport, with the host doing the HTTP. The return codes are SWORD's (CURLHTTPTransport's): 0 success, -1 terminated
// by the user, -2 timed out, -3 access denied, -5 an HTTP error status, -10 anything else.
class CallbackTransport : public sword::RemoteTransport {
public:
	CallbackTransport(const char *host, sword::StatusReporter *reporter) : sword::RemoteTransport(host, reporter) {}

	virtual char getURL(const char *destPath, const char *sourceURL, sword::SWBuf *destBuf = 0) {
		if(!gFetch) {
			return -10;
		}
		struct swx_http_request request;
		request.url = sourceURL;
		request.user = u.c_str();
		request.password = p.c_str();
		request.timeout_ms = timeoutMillis;
		request.allow_unverified = isUnverifiedPeerAllowed() ? 1 : 0;
		struct swx_http_hooks hooks;
		hooks.progress = &CallbackTransport::reportProgress;
		hooks.cancelled = &CallbackTransport::isCancelled;
		hooks.transport = this;

		unsigned char *body = 0;
		unsigned long length = 0;
		int code = gFetch(gFetchContext, &request, &hooks, &body, &length);
		if(code != 0) {
			free(body);
			sword::SWLog::getSystemLog()->logWarning("CallbackTransport: %s failed, code %d\n", sourceURL, code);
			return (char)code;
		}
		char result = 0;
		if(destBuf) {
			unsigned long size = destBuf->size();
			destBuf->size(size + length);
			if(length) {
				memcpy(destBuf->getRawData() + size, body, length);
			}
		} else {
			int fd = sword::FileMgr::createPathAndFile(destPath);
			if(fd < 0) {
				result = -10;
			} else {
				if(length && sword::FileMgr::write(fd, body, (long)length) != (long)length) {
					result = -10;
				}
				sword::FileMgr::closeFile(fd);
			}
		}
		free(body);
		if(!result && statusReporter) {
			statusReporter->update(length, length);
		}
		return result;
	}

	// An HTTP directory index (Apache's or nginx's), parsed as CURLHTTPTransport does.
	virtual std::vector<struct sword::DirEntry> getDirList(const char *dirURL) {
		std::vector<struct sword::DirEntry> dirList;
		sword::SWBuf dirBuf;
		if(getURL("", dirURL, &dirBuf)) {
			sword::SWLog::getSystemLog()->logWarning("CallbackTransport::getDirList: failed to get dir %s\n", dirURL);
			return dirList;
		}
		const char *cursor = strstr(dirBuf.c_str(), "<a href=\"");
		while(cursor) {
			cursor += 9;   // to the start of the name
			const char *end = strchr(cursor, '"');
			if(!end) {
				break;
			}
			const int nameLength = (int)(end - cursor);
			sword::SWBuf name;
			name.setFormatted("%.*s", nameLength, cursor);
			if(isalnum((unsigned char)name[0])) {
				cursor = end;
				double size = 0;
				const char *sizeStart = findSizeStart(cursor);
				if(sizeStart) {
					char *after = 0;
					size = strtod(sizeStart, &after);
					if(after[0] == 'K') size *= 1024;
					else if(after[0] == 'M') size *= 1048576;
					cursor = after;
				}
				struct sword::DirEntry entry;
				entry.name = name;
				entry.size = (long unsigned int)size;
				entry.isDirectory = name.endsWith("/");
				dirList.push_back(entry);
			} else {
				cursor += nameLength;
			}
			cursor++;
			cursor = strstr(cursor, "<a href=\"");
		}
		return dirList;
	}

private:
	// the size column of a directory index row: the second cell after the link
	static const char *findSizeStart(const char *buffer) {
		const char *listing = buffer;
		const char *cell = strstr(listing, "<td");
		if(!cell) return 0;
		listing = cell + 2;
		cell = strstr(listing, "<td");
		if(!cell) return 0;
		listing = cell + 2;
		cell = strchr(listing, '>');
		return cell ? cell + 1 : 0;
	}

	static void reportProgress(void *transport, unsigned long total, unsigned long completed) {
		CallbackTransport *self = (CallbackTransport *)transport;
		if(self && self->statusReporter) {
			self->statusReporter->update(total, completed);
		}
	}

	static int isCancelled(void *transport) {
		CallbackTransport *self = (CallbackTransport *)transport;
		return (self && self->term) ? 1 : 0;
	}
};

// Downloads are HTTPS or HTTP, through the host. With no FTP transport InstallMgr::remoteCopy() returns -9 ("transport not
// available") for a source of type FTP.
class EBInstallMgr : public sword::InstallMgr {
public:
	using sword::InstallMgr::InstallMgr;
protected:
	sword::RemoteTransport *createFTPTransport(const char *, sword::StatusReporter *) override { return nullptr; }
	sword::RemoteTransport *createHTTPTransport(const char *host, sword::StatusReporter *reporter) override {
		return gFetch ? new CallbackTransport(host, reporter) : sword::InstallMgr::createHTTPTransport(host, reporter);
	}
};

class EBStatusReporter : public sword::StatusReporter {
public:
	swx_status_callback callback;
	void *context;
	EBStatusReporter(swx_status_callback callback, void *context) : callback(callback), context(context) {}
	virtual void update(unsigned long totalBytes, unsigned long completedBytes) {
		if(callback) callback("update", totalBytes, completedBytes, context);
	}
	virtual void preStatus(long totalBytes, long completedBytes, const char *message) {
		if(callback) callback(message ? message : "", (unsigned long)totalBytes, (unsigned long)completedBytes, context);
	}
};

struct InstallState {
	std::string baseDir;
	std::unique_ptr<EBStatusReporter> reporter;
};

std::mutex installRegistryLock;
std::map<HandleInstMgr *, InstallState> installRegistry;

const char *const kTypeFTP = "FTPSource";
const char *const kTypeHTTP = "HTTPSource";
const char *const kTypeHTTPS = "HTTPSSource";
// InstallMgr chains an entry filed under this section onto the HTTPSSource entry of the same caption, and tries a single
// packages/<module>.zip plus mods.d.tar.gz download against it before the per-file directory listing.
const char *const kTypePackagePreference = "HTTPSPackagePreference";
const char *const kPackageUIDSuffix = "-pkg";

struct SourceRecord {
	std::string type;      // "HTTPS", "HTTP", "FTP"
	std::string caption, source, directory, uid;
	bool packagePreference;
};

std::vector<std::string> splitFields(const std::string &text) {
	std::vector<std::string> fields;
	size_t start = 0;
	for(;;) {
		size_t bar = text.find('|', start);
		fields.push_back(text.substr(start, bar == std::string::npos ? std::string::npos : bar - start));
		if(bar == std::string::npos) break;
		start = bar + 1;
	}
	return fields;
}

std::string entryFor(const SourceRecord &record, bool package) {
	return record.caption + "|" + record.source + "|" + record.directory + "|||" + record.uid + (package ? kPackageUIDSuffix : "");
}

const char *sectionKeyFor(const std::string &type) {
	if(type == "FTP") return kTypeFTP;
	if(type == "HTTPS") return kTypeHTTPS;
	return kTypeHTTP;
}

void writeSources(sword::SWConfig &config, const std::vector<SourceRecord> &records) {
	sword::ConfigEntMap &sources = config["Sources"];
	sources.erase(kTypeFTP);
	sources.erase(kTypeHTTP);
	sources.erase(kTypeHTTPS);
	sources.erase(kTypePackagePreference);
	for(size_t i = 0; i < records.size(); ++i) {
		sources.insert(sword::ConfigEntMap::value_type(sectionKeyFor(records[i].type), entryFor(records[i], false).c_str()));
		if(records[i].packagePreference) {
			sources.insert(sword::ConfigEntMap::value_type(kTypePackagePreference, entryFor(records[i], true).c_str()));
		}
	}
}

std::vector<SourceRecord> readSources(sword::SWConfig &config) {
	std::vector<SourceRecord> records;
	sword::SectionMap::iterator section = config.getSections().find("Sources");
	if(section == config.getSections().end()) {
		return records;
	}
	const struct { const char *key; const char *type; } types[] = { { kTypeFTP, "FTP" }, { kTypeHTTP, "HTTP" }, { kTypeHTTPS, "HTTPS" } };
	for(size_t t = 0; t < 3; ++t) {
		std::pair<sword::ConfigEntMap::iterator, sword::ConfigEntMap::iterator> range = section->second.equal_range(types[t].key);
		for(sword::ConfigEntMap::iterator it = range.first; it != range.second; ++it) {
			std::vector<std::string> fields = splitFields(it->second.c_str());
			if(fields.size() < 3) continue;
			SourceRecord record;
			record.type = types[t].type;
			record.caption = fields[0];
			record.source = fields[1];
			record.directory = fields[2];
			record.uid = fields.size() > 5 ? fields.back() : "";
			record.packagePreference = false;
			records.push_back(record);
		}
	}
	std::pair<sword::ConfigEntMap::iterator, sword::ConfigEntMap::iterator> packages = section->second.equal_range(kTypePackagePreference);
	for(sword::ConfigEntMap::iterator it = packages.first; it != packages.second; ++it) {
		std::vector<std::string> fields = splitFields(it->second.c_str());
		for(size_t i = 0; i < records.size(); ++i) {
			if(!fields.empty() && records[i].caption == fields[0]) records[i].packagePreference = true;
		}
	}
	return records;
}

// Confs written before the package-preference entry had a uid of its own filed both entries under one uid, which empties the
// module list (InstallMgr treats the second as a duplicate). Give each such entry its own.
void giveEachPackagePreferenceItsOwnUID(const std::string &confPath) {
	sword::SWConfig config(confPath.c_str());
	sword::SectionMap::iterator section = config.getSections().find("Sources");
	if(section == config.getSections().end()) {
		return;
	}
	std::vector<std::string> entries;
	bool changed = false;
	std::pair<sword::ConfigEntMap::iterator, sword::ConfigEntMap::iterator> range = section->second.equal_range(kTypePackagePreference);
	for(sword::ConfigEntMap::iterator it = range.first; it != range.second; ++it) {
		std::vector<std::string> fields = splitFields(it->second.c_str());
		const std::string uid = fields.empty() ? "" : fields.back();
		const std::string suffix = kPackageUIDSuffix;
		const bool hasSuffix = uid.size() >= suffix.size() && uid.compare(uid.size() - suffix.size(), suffix.size(), suffix) == 0;
		if(fields.size() >= 6 && !uid.empty() && !hasSuffix) {
			fields.back() = uid + suffix;
			changed = true;
		}
		std::string joined;
		for(size_t i = 0; i < fields.size(); ++i) joined += (i ? "|" : "") + fields[i];
		entries.push_back(joined);
	}
	if(!changed) {
		return;
	}
	section->second.erase(kTypePackagePreference);
	for(size_t i = 0; i < entries.size(); ++i) {
		section->second.insert(sword::ConfigEntMap::value_type(kTypePackagePreference, entries[i].c_str()));
	}
	config.save();
}

// The sources a new install has. All but the last also serve packages/<module>.zip and mods.d.tar.gz beside the per-file tree.
void writeDefaultSources(const std::string &confPath) {
	sword::FileMgr::createParent(confPath.c_str());
	sword::SWConfig config(confPath.c_str());
	config["General"]["PassiveFTP"] = "true";
	const SourceRecord defaults[] = {
		{ "HTTPS", "CrossWire (https)", "crosswire.org", "/ftpmirror/pub/sword/raw/", "20081216195755", true },
		{ "HTTPS", "eBible.org (https)", "eBible.org", "/sword/", "20190314213800", true },
		{ "HTTPS", "CrossWire Beta (https)", "crosswire.org", "/ftpmirror/pub/sword/betaraw/", "20120224005000", true },
		{ "HTTPS", "Deutsche Bibelgesellschaft (https)", "crosswire.org", "/ftpmirror/pub/sword/dbgraw/", "20120224005001", true },
		{ "HTTPS", "IBT (https)", "ibt.org.ru", "/pub/modsword/raw", "20120224005000", false },
	};
	writeSources(config, std::vector<SourceRecord>(defaults, defaults + 5));
	config.save();
}

HandleInstMgr *handleFor(SWXHANDLE install) {
	std::lock_guard<std::mutex> guard(installRegistryLock);
	HandleInstMgr *handle = (HandleInstMgr *)install;
	return installRegistry.count(handle) ? handle : 0;
}

// InstallMgr reads its configuration when it is made, so a change to the file is followed by a new one. The disclaimer the
// reader confirmed is kept.
void reload(HandleInstMgr *handle) {
	InstallState &state = installRegistry[handle];
	const bool disclaimer = handle->installMgr ? handle->installMgr->isUserDisclaimerConfirmed() : false;
	delete handle->installMgr;
	giveEachPackagePreferenceItsOwnUID(state.baseDir + "/InstallMgr.conf");
	handle->installMgr = new EBInstallMgr(state.baseDir.c_str(), state.reporter.get(), "ftp", "installmgr@pocketsword.crosswire.org");
	handle->installMgr->setUserDisclaimerConfirmed(disclaimer);
}

} // namespace

extern "C" void swx_set_http_fetch(swx_http_fetch fetch, void *context) {
	gFetch = fetch;
	gFetchContext = context;
}

extern "C" SWXHANDLE swx_install_new(const char *baseDir, int resetSources, swx_status_callback status, void *context) {
	if(!baseDir) {
		return 0;
	}
	const std::string confPath = std::string(baseDir) + "/InstallMgr.conf";
	if(resetSources) {
		remove(confPath.c_str());
	}
	if(!sword::FileMgr::existsFile(confPath.c_str())) {
		writeDefaultSources(confPath);
	}
	std::lock_guard<std::mutex> guard(installRegistryLock);
	HandleInstMgr *handle = new HandleInstMgr();
	InstallState &state = installRegistry[handle];
	state.baseDir = baseDir;
	state.reporter.reset(new EBStatusReporter(status, context));
	handle->installMgr = 0;
	reload(handle);
	return (SWXHANDLE)handle;
}

extern "C" void swx_install_delete(SWXHANDLE install) {
	HandleInstMgr *handle = handleFor(install);
	if(!handle) {
		return;
	}
	delete handle;   // frees the install manager
	std::lock_guard<std::mutex> guard(installRegistryLock);
	installRegistry.erase(handle);
}

extern "C" struct swx_source *swx_install_sources(SWXHANDLE install, int *count) {
	if(!count) {
		return 0;
	}
	*count = 0;
	HandleInstMgr *handle = handleFor(install);
	if(!handle) {
		return 0;
	}
	sword::SWConfig config((installRegistry[handle].baseDir + "/InstallMgr.conf").c_str());
	std::vector<SourceRecord> records = readSources(config);
	*count = (int)records.size();
	struct swx_source *sources = (struct swx_source *)calloc(records.size() > 0 ? records.size() : 1, sizeof(struct swx_source));
	for(size_t i = 0; i < records.size(); ++i) {
		sources[i].type = copyString(records[i].type);
		sources[i].caption = copyString(records[i].caption);
		sources[i].source = copyString(records[i].source);
		sources[i].directory = copyString(records[i].directory);
		sources[i].uid = copyString(records[i].uid);
		sources[i].package_preference = records[i].packagePreference ? 1 : 0;
	}
	return sources;
}

extern "C" void swx_free_sources(struct swx_source *sources, int count) {
	if(!sources) {
		return;
	}
	for(int i = 0; i < count; ++i) {
		free(sources[i].type);
		free(sources[i].caption);
		free(sources[i].source);
		free(sources[i].directory);
		free(sources[i].uid);
	}
	free(sources);
}

extern "C" int swx_install_add_source(SWXHANDLE install, const struct swx_source *source) {
	HandleInstMgr *handle = handleFor(install);
	if(!handle || !source || !source->type || !source->caption || !source->source || !source->directory) {
		return -1;
	}
	const std::string confPath = installRegistry[handle].baseDir + "/InstallMgr.conf";
	sword::SWConfig config(confPath.c_str());
	std::vector<SourceRecord> records = readSources(config);
	SourceRecord record;
	record.type = source->type;
	record.caption = source->caption;
	record.source = source->source;
	record.directory = source->directory;
	record.uid = source->uid ? source->uid : "";
	record.packagePreference = source->package_preference != 0;
	records.push_back(record);
	writeSources(config, records);
	config.save();
	std::lock_guard<std::mutex> guard(installRegistryLock);
	reload(handle);
	return 0;
}

extern "C" int swx_install_remove_source(SWXHANDLE install, const char *caption) {
	HandleInstMgr *handle = handleFor(install);
	if(!handle || !caption) {
		return -1;
	}
	const std::string confPath = installRegistry[handle].baseDir + "/InstallMgr.conf";
	sword::SWConfig config(confPath.c_str());
	std::vector<SourceRecord> records = readSources(config);
	std::vector<SourceRecord> kept;
	for(size_t i = 0; i < records.size(); ++i) {
		if(records[i].caption != caption) kept.push_back(records[i]);
	}
	writeSources(config, kept);
	config.save();
	std::lock_guard<std::mutex> guard(installRegistryLock);
	reload(handle);
	return 0;
}

// ---- A module's facts, entries and passages ----------------------------------------------------------------------------------

namespace {

bool configHas(sword::SWModule *module, const char *section, const std::string &value) {
	return module->getConfig().has(section, value.c_str());
}

// SWORD marks a feature on a module with a Feature entry or a GlobalOptionFilter naming a filter for it, in each markup's prefix.
bool moduleHasFeature(sword::SWModule *module, const std::string &feature) {
	if(configHas(module, "Feature", feature)) return true;
	const char *prefixes[] = { "GBF", "ThML", "UTF8", "OSIS", "" };
	for(size_t i = 0; i < 5; ++i) {
		if(configHas(module, "GlobalOptionFilter", std::string(prefixes[i]) + feature)) return true;
	}
	return false;
}

std::string configEntry(sword::SWModule *module, const char *key, bool *present) {
	const char *value = module->getConfigEntry(key);
	if(present) *present = (value != 0);
	return value ? value : "";
}

// "  3588 " -> "3588"; "03588" -> "3588"; case folded: the keys of a dictionary are compared this way
std::string normalisedKey(const std::string &key) {
	size_t begin = key.find_first_not_of(" \t\r\n");
	if(begin == std::string::npos) return "";
	size_t end = key.find_last_not_of(" \t\r\n");
	std::string k = key.substr(begin, end - begin + 1);
	for(size_t i = 0; i < k.size(); ++i) k[i] = (char)tolower((unsigned char)k[i]);
	bool allDigits = !k.empty();
	for(size_t i = 0; i < k.size(); ++i) if(!isdigit((unsigned char)k[i])) allDigits = false;
	if(allDigits) {
		size_t nonZero = k.find_first_not_of('0');
		return nonZero == std::string::npos ? "0" : k.substr(nonZero);
	}
	return k;
}

} // namespace

extern "C" int swx_module_info(SWXHANDLE handle, struct swx_module_info *out) {
	if(!out) {
		return -1;
	}
	memset(out, 0, sizeof(*out));
	HandleSWModule *hmod = (HandleSWModule *)handle;
	if(!hmod || !hmod->mod) {
		return -1;
	}
	sword::SWModule *module = hmod->mod;
	std::lock_guard<std::recursive_mutex> guard(lockFor(module));
	bool present = false;
	const std::string sourceType = configEntry(module, "SourceType", &present);
	out->source_type = present ? copyString(sourceType) : 0;
	const std::string versification = configEntry(module, "Versification", &present);
	out->versification = copyString(present && !versification.empty() ? versification : std::string("KJV"));
	out->right_to_left = (configEntry(module, "Direction", 0) == "RtoL") ? 1 : 0;
	out->unicode = module->isUnicode() ? 1 : 0;
	out->osis_q_to_tick = (configEntry(module, "OSISqToTick", 0) == "false") ? 0 : 1;
	out->verse_keyed = SWDYNAMIC_CAST(VerseKey, module->getKey()) ? 1 : 0;
	out->declares_greek_accents = moduleHasFeature(module, "GreekAccents") ? 1 : 0;
	out->declares_hebrew_points = moduleHasFeature(module, "HebrewPoints") ? 1 : 0;
	out->declares_cantillation = moduleHasFeature(module, "Cantillation") ? 1 : 0;
	out->type = copyString(decode(module->getType(), true));
	const std::string category = configEntry(module, "Category", &present);
	out->category = present ? copyString(category) : 0;
	out->description = copyString(decode(module->getDescription(), true));
	const std::string language = configEntry(module, "Lang", &present);
	out->language = present ? copyString(language) : 0;
	const std::string version = configEntry(module, "Version", &present);
	out->version = present ? copyString(version) : 0;
	const std::string cipherKey = configEntry(module, "CipherKey", &present);
	out->cipher_key = present ? copyString(cipherKey) : 0;
	return 0;
}

extern "C" void swx_free_module_info(struct swx_module_info *info) {
	if(!info) {
		return;
	}
	free(info->source_type);
	free(info->versification);
	free(info->type);
	free(info->category);
	free(info->description);
	free(info->language);
	free(info->version);
	free(info->cipher_key);
	memset(info, 0, sizeof(*info));
}

extern "C" int swx_read_entry(SWXHANDLE handle, const char *key, char **foundKey, char **raw) {
	if(!foundKey || !raw) {
		return -1;
	}
	*foundKey = 0;
	*raw = 0;
	HandleSWModule *hmod = (HandleSWModule *)handle;
	if(!hmod || !hmod->mod || !key || !*key) {
		return -1;
	}
	sword::SWModule *module = hmod->mod;
	std::lock_guard<std::recursive_mutex> guard(lockFor(module));
	if(SWDYNAMIC_CAST(VerseKey, module->getKey())) {
		return -2;   // a Bible or commentary
	}
	const std::string wanted = normalisedKey(key);
	std::vector<std::string> candidates;
	candidates.push_back(key);
	bool numeric = !wanted.empty();
	for(size_t i = 0; i < wanted.size(); ++i) if(!isdigit((unsigned char)wanted[i])) numeric = false;
	if(numeric) {
		// the zero-padded forms: the Strong's modules hold "3588" or "03588" or "00001"
		candidates.push_back(wanted);
		for(size_t width = 4; width <= 5; ++width) {
			if(wanted.size() < width) candidates.push_back(std::string(width - wanted.size(), '0') + wanted);
		}
	}
	const bool unicode = module->isUnicode();
	for(size_t i = 0; i < candidates.size(); ++i) {
		module->setKey(candidates[i].c_str());
		// a dictionary finds its entry when it is read, and then names the key it found
		const char *bytes = module->getRawEntry();
		if(module->popError()) {
			continue;
		}
		const std::string actual = decode(module->getKeyText(), true);
		if(normalisedKey(actual) != wanted) {
			continue;   // the index put us on a neighbouring entry
		}
		*foundKey = copyString(actual);
		*raw = copyString(decode(bytes, unicode));
		return 0;
	}
	return -3;
}

extern "C" int swx_read_stripped(SWXHANDLE handle, const char *key, char **text) {
	if(!text) {
		return -1;
	}
	*text = 0;
	HandleSWModule *hmod = (HandleSWModule *)handle;
	if(!hmod || !hmod->mod || !key || !*key) {
		return -1;
	}
	sword::SWModule *module = hmod->mod;
	std::lock_guard<std::recursive_mutex> guard(lockFor(module));
	module->setKey(key);
	if(module->popError()) {
		return -3;
	}
	const sword::SWBuf stripped = module->stripText();
	*text = copyString(decode(stripped.c_str(), true));
	return 0;
}

extern "C" char **swx_dictionary_keys(SWXHANDLE handle, int *count) {
	if(!count) {
		return 0;
	}
	*count = 0;
	HandleSWModule *hmod = (HandleSWModule *)handle;
	if(!hmod || !hmod->mod) {
		return 0;
	}
	std::lock_guard<std::recursive_mutex> guard(lockFor(hmod->mod));
	sword::SWModule *module = hmod->mod;
	std::vector<std::string> keys;
	module->setSkipConsecutiveLinks(true);
	*module = sword::TOP;
	module->getRawEntry();
	while(!module->popError()) {
		const char *text = module->getKeyText();
		if(text) {
			keys.push_back(text);
		}
		(*module)++;
	}
	*count = (int)keys.size();
	char **result = (char **)calloc(keys.size() > 0 ? keys.size() : 1, sizeof(char *));
	for(size_t i = 0; i < keys.size(); ++i) {
		result[i] = copyString(keys[i]);
	}
	return result;
}

extern "C" char **swx_parse_passage(const char *reference, const char *versification, int *count) {
	if(!count) {
		return 0;
	}
	*count = 0;
	if(!reference || !*reference) {
		return 0;
	}
	sword::VerseKey parser;
	if(versification && *versification) {
		parser.setVersificationSystem(versification);
	}
	sword::ListKey list = parser.parseVerseList(reference, "Gen 1:1", true);
	std::vector<std::string> verses;
	for(list.setPosition(sword::TOP); !list.popError(); list.increment()) {
		sword::SWKey *element = list.getElement();
		const char *text = element ? element->getText() : list.getText();
		if(text && *text) {
			verses.push_back(text);
		}
	}
	*count = (int)verses.size();
	char **result = (char **)calloc(verses.size() > 0 ? verses.size() : 1, sizeof(char *));
	for(size_t i = 0; i < verses.size(); ++i) {
		result[i] = copyString(verses[i]);
	}
	return result;
}

// ---- Searching ----------------------------------------------------------------------------------------------------------------

namespace {

// The scope of a search, built as the Objective-C SwordVerseKey did: lower and upper bounds on a verse key.
void boundWholeBible(sword::VerseKey &key) {
	key.setPosition(sword::TOP);
	key.setLowerBound(key);
	key.setPosition(sword::BOTTOM);
	key.setUpperBound(key);
}

void boundOldTestament(sword::VerseKey &key) {
	key.setPosition(sword::TOP);
	key.setLowerBound(key);
	key.setTestament(2);
	key--;   // the verse before the New Testament: MAXBOOK is not implemented in versekey.cpp
	key.setUpperBound(key);
}

void boundNewTestament(sword::VerseKey &key) {
	key.setPosition(sword::TOP);   // sets book, chapter and verse to 1, which setTestament does not
	key.setTestament(2);
	key.setLowerBound(key);
	key.setPosition(sword::BOTTOM);
	key.setUpperBound(key);
}

void boundBook(sword::VerseKey &key, const char *reference) {
	key.setText(reference);
	key.setChapter(1);
	key.setVerse(1);
	key.setLowerBound(key);
	key.setChapter(key.getChapterMax());
	key.setVerse(key.getVerseMax());
	key.setUpperBound(key);
}

bool hasIndex(sword::SWModule *module) {
	bool supported = false;
	module->search("", sword::SWModule::SEARCHTYPE_EXTERNAL, 0, 0, &supported);
	return supported;
}

} // namespace

extern "C" int swx_has_search_index(SWXHANDLE handle) {
	HandleSWModule *hmod = (HandleSWModule *)handle;
	if(!hmod || !hmod->mod) {
		return 0;
	}
	std::lock_guard<std::recursive_mutex> guard(lockFor(hmod->mod));
	return hasIndex(hmod->mod) ? 1 : 0;
}

extern "C" char **swx_search(SWXHANDLE handle, const char *term, int range, const char *bookReference, const char *versification,
                                  int *count, int *usedIndex) {
	if(count) *count = 0;
	if(usedIndex) *usedIndex = 0;
	HandleSWModule *hmod = (HandleSWModule *)handle;
	if(!hmod || !hmod->mod || !term || !count) {
		return 0;
	}
	sword::SWModule *module = hmod->mod;
	std::lock_guard<std::recursive_mutex> guard(lockFor(module));

	// -4 is CLucene's search; 0 is a regular expression
	const bool indexed = hasIndex(module);
	if(usedIndex) *usedIndex = indexed ? 1 : 0;
	const int searchType = indexed ? -4 : 0;

	sword::ListKey results;
	if(range != EB_SEARCH_ALL && SWDYNAMIC_CAST(VerseKey, module->getKey())) {
		sword::VerseKey scope;
		scope.setVersificationSystem(versification && *versification ? versification : "KJV");
		switch(range) {
			case EB_SEARCH_OLD_TESTAMENT: boundOldTestament(scope); break;
			case EB_SEARCH_NEW_TESTAMENT: boundNewTestament(scope); break;
			case EB_SEARCH_BOOK: boundBook(scope, bookReference ? bookReference : ""); break;
			default: boundWholeBible(scope); break;
		}
		results = module->search(term, searchType, REG_ICASE, &scope);
	} else if(range == EB_SEARCH_ALL && SWDYNAMIC_CAST(VerseKey, module->getKey())) {
		sword::VerseKey scope;
		scope.setVersificationSystem(versification && *versification ? versification : "KJV");
		boundWholeBible(scope);
		results = module->search(term, searchType, REG_ICASE, &scope);
	} else {
		results = module->search(term, searchType, REG_ICASE);
	}
	results.sort();

	std::vector<std::string> keys;
	if(results.getCount() > 0) {
		while(!results.popError()) {
			keys.push_back(decode(results.getText(), true));
			results++;
		}
	}
	*count = (int)keys.size();
	char **hits = (char **)calloc(keys.size() > 0 ? keys.size() : 1, sizeof(char *));
	for(size_t i = 0; i < keys.size(); ++i) {
		hits[i] = copyString(keys[i]);
	}
	return hits;
}

extern "C" void swx_init_locale(const char *localesFolder, const char **preferred, int count) {
	sword::LocaleMgr *locales = sword::LocaleMgr::getSystemLocaleMgr();
	if(localesFolder && *localesFolder) {
		locales->loadConfigDir(localesFolder);
	}
	sword::StringList available = locales->getAvailableLocales();
	for(int i = 0; i < count; ++i) {
		std::string wanted = preferred[i] ? preferred[i] : "";
		for(size_t at = wanted.find('-'); at != std::string::npos; at = wanted.find('-')) {
			wanted[at] = '_';   // SWORD and the system write locales differently
		}
		std::string candidates[2] = { wanted, wanted.substr(0, wanted.find('_')) };
		for(int c = 0; c < 2; ++c) {
			if(candidates[c].empty() || (c == 1 && candidates[1] == candidates[0])) continue;
			for(sword::StringList::iterator it = available.begin(); it != available.end(); ++it) {
				if(strncmp(it->c_str(), candidates[c].c_str(), candidates[c].size()) == 0) {
					locales->setDefaultLocaleName(it->c_str());
					return;
				}
			}
		}
	}
}

extern "C" char **swx_install_from_folder(SWXHANDLE library, const char *folder, int *count) {
	if(!count) {
		return 0;
	}
	*count = 0;
	HandleSWMgr *hmgr = (HandleSWMgr *)library;
	if(!hmgr || !hmgr->mgr || !folder || !*folder) {
		return 0;
	}
	sword::InstallMgr installer;
	sword::SWMgr source(folder);
	std::vector<std::string> names;
	for(sword::ModMap::iterator it = source.Modules.begin(); it != source.Modules.end(); ++it) {
		sword::SWModule *module = it->second;
		if(module && installer.installModule(hmgr->mgr, folder, module->getName()) == 0) {
			names.push_back(module->getName());
		}
	}
	*count = (int)names.size();
	char **result = (char **)calloc(names.size() > 0 ? names.size() : 1, sizeof(char *));
	for(size_t i = 0; i < names.size(); ++i) {
		result[i] = copyString(names[i]);
	}
	return result;
}

extern "C" int swx_module_config_entry(SWXHANDLE handle, const char *key, char **value) {
	HandleSWModule *hmod = (HandleSWModule *)handle;
	if(!hmod || !hmod->mod || !key || !value) {
		return -1;
	}
	std::lock_guard<std::recursive_mutex> guard(lockFor(hmod->mod));
	bool present = false;
	std::string entry = configEntry(hmod->mod, key, &present);
	if(!present) {
		return -3;
	}
	*value = strdup(entry.c_str());
	return 0;
}

extern "C" int swx_module_has_feature(SWXHANDLE handle, const char *feature) {
	HandleSWModule *hmod = (HandleSWModule *)handle;
	if(!hmod || !hmod->mod || !feature) {
		return 0;
	}
	std::lock_guard<std::recursive_mutex> guard(lockFor(hmod->mod));
	return moduleHasFeature(hmod->mod, feature) ? 1 : 0;
}
