// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd
//
// JNI over the C layer that SwordProvider uses on iOS: the flat API's library, module and install-manager calls it needs
// (flatapi.h) and our swx_* functions (sword_flat_ext.h). The Kotlin class is org.logoshub.sword.SwordNative (Android/). Everything
// crosses as handles (long), strings and arrays of strings, so there is no Java object to build from C++ except the callbacks'
// arguments; Kotlin shapes the arrays into types (SwordLibrary.kt). Strings are converted through UTF-8 bytes: NewStringUTF and
// GetStringUTFChars use "modified UTF-8", which breaks on characters outside the BMP.

#include <jni.h>
#include <stdlib.h>
#include <string.h>
#include <map>
#include <mutex>
#include <string>
#include <vector>

#include "flatapi.h"
#include "sword_flat_ext.h"

#define JNI_FN(ret, name) extern "C" JNIEXPORT ret JNICALL Java_org_logoshub_sword_SwordNative_##name

namespace {

JavaVM *gVM = nullptr;
jclass gStringClass = nullptr;
jmethodID gStringFromBytes = nullptr;   // String(byte[], String)
jmethodID gStringGetBytes = nullptr;    // byte[] getBytes(String)
jclass gProgressClass = nullptr;        // SwordNative.ProgressListener
jmethodID gOnProgress = nullptr;
jclass gStatusClass = nullptr;          // SwordNative.StatusListener
jmethodID gOnStatus = nullptr;
jclass gFetcherClass = nullptr;         // SwordNative.HttpFetcher
jmethodID gFetch = nullptr;
jclass gHttpErrorClass = nullptr;       // SwordNative.HttpError
jfieldID gHttpErrorCode = nullptr;
jclass gHooksClass = nullptr;           // SwordNative.HttpHooks
jmethodID gHooksInit = nullptr;

/// The calling thread's env, attaching it to the VM when it is a native thread.
JNIEnv *env() {
	JNIEnv *e = nullptr;
	if (gVM->GetEnv((void **)&e, JNI_VERSION_1_6) == JNI_OK) return e;
	if (gVM->AttachCurrentThread(&e, nullptr) == JNI_OK) return e;
	return nullptr;
}

jstring toJ(JNIEnv *e, const char *utf8) {
	if (!utf8) return nullptr;
	size_t n = strlen(utf8);
	jbyteArray bytes = e->NewByteArray((jsize)n);
	e->SetByteArrayRegion(bytes, 0, (jsize)n, (const jbyte *)utf8);
	jstring charset = e->NewStringUTF("UTF-8");
	jstring s = (jstring)e->NewObject(gStringClass, gStringFromBytes, bytes, charset);
	e->DeleteLocalRef(charset);
	e->DeleteLocalRef(bytes);
	return s;
}

std::string fromJ(JNIEnv *e, jstring s) {
	if (!s) return std::string();
	jstring charset = e->NewStringUTF("UTF-8");
	jbyteArray bytes = (jbyteArray)e->CallObjectMethod(s, gStringGetBytes, charset);
	e->DeleteLocalRef(charset);
	jsize n = e->GetArrayLength(bytes);
	std::string out((size_t)n, '\0');
	if (n) e->GetByteArrayRegion(bytes, 0, n, (jbyte *)&out[0]);
	e->DeleteLocalRef(bytes);
	return out;
}

/// A Java String[] from C strings (a null C string is a null element).
jobjectArray toArray(JNIEnv *e, const std::vector<const char *> &items) {
	jobjectArray array = e->NewObjectArray((jsize)items.size(), gStringClass, nullptr);
	for (size_t i = 0; i < items.size(); i++) {
		jstring s = toJ(e, items[i]);
		e->SetObjectArrayElement(array, (jsize)i, s);
		if (s) e->DeleteLocalRef(s);
	}
	return array;
}

jobjectArray toArrayAndFree(JNIEnv *e, char **list, int count) {
	std::vector<const char *> items(list, list + count);
	jobjectArray array = toArray(e, items);
	swx_free_strings(list, count);
	return array;
}

std::vector<std::string> arrayToStrings(JNIEnv *e, jobjectArray array) {
	std::vector<std::string> out;
	if (!array) return out;
	jsize n = e->GetArrayLength(array);
	for (jsize i = 0; i < n; i++) {
		jstring s = (jstring)e->GetObjectArrayElement(array, i);
		out.push_back(fromJ(e, s));
		if (s) e->DeleteLocalRef(s);
	}
	return out;
}

std::string itoa(long long v) { return std::to_string(v); }

// --- callbacks --------------------------------------------------------------------------------------------------------------

struct ProgressContext { jobject listener; };

void progressCallback(int percent, void *context) {
	auto *c = (ProgressContext *)context;
	JNIEnv *e = env();
	if (e && c && c->listener) e->CallVoidMethod(c->listener, gOnProgress, (jint)percent);
}

struct StatusContext { jobject listener; };
std::mutex gStatusMutex;
std::map<intptr_t, StatusContext *> gStatus;   // install manager handle -> its listener (global reference)

void statusCallback(const char *message, unsigned long total, unsigned long completed, void *context) {
	auto *c = (StatusContext *)context;
	JNIEnv *e = env();
	if (!e || !c || !c->listener) return;
	jstring m = toJ(e, message);
	e->CallVoidMethod(c->listener, gOnStatus, m, (jlong)total, (jlong)completed);
	if (m) e->DeleteLocalRef(m);
	if (e->ExceptionCheck()) e->ExceptionClear();
}

jobject gFetcher = nullptr;   // global reference to the host's HttpFetcher

int fetchCallback(void *, const struct swx_http_request *request, const struct swx_http_hooks *hooks, unsigned char **body,
                  unsigned long *length) {
	JNIEnv *e = env();
	if (!e || !gFetcher) return -10;
	jstring url = toJ(e, request->url), user = toJ(e, request->user), password = toJ(e, request->password);
	// the hooks are valid only during this call: Kotlin gets the address and gives it back to hookProgress and hookCancelled
	jobject h = e->NewObject(gHooksClass, gHooksInit, (jlong)(intptr_t)hooks);
	jbyteArray result = (jbyteArray)e->CallObjectMethod(gFetcher, gFetch, url, user, password, (jlong)request->timeout_ms,
	                                                    (jboolean)(request->allow_unverified != 0), h);
	int code = 0;
	if (e->ExceptionCheck()) {
		jthrowable t = e->ExceptionOccurred();
		e->ExceptionClear();
		code = e->IsInstanceOf(t, gHttpErrorClass) ? e->GetIntField(t, gHttpErrorCode) : -10;
		e->DeleteLocalRef(t);
	} else if (!result) {
		code = -10;
	} else {
		jsize n = e->GetArrayLength(result);
		unsigned char *copy = (unsigned char *)malloc(n ? (size_t)n : 1);
		if (n) e->GetByteArrayRegion(result, 0, n, (jbyte *)copy);
		*body = copy;
		*length = (unsigned long)n;
	}
	if (result) e->DeleteLocalRef(result);
	e->DeleteLocalRef(h);
	if (url) e->DeleteLocalRef(url);
	if (user) e->DeleteLocalRef(user);
	if (password) e->DeleteLocalRef(password);
	return code;
}

SWHANDLE H(jlong h) { return (SWHANDLE)h; }
SWXHANDLE X(jlong h) { return (SWXHANDLE)h; }

}  // namespace

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *) {
	gVM = vm;
	JNIEnv *e = nullptr;
	if (vm->GetEnv((void **)&e, JNI_VERSION_1_6) != JNI_OK) return JNI_ERR;
	auto cls = [&](const char *name) { return (jclass)e->NewGlobalRef(e->FindClass(name)); };
	gStringClass = cls("java/lang/String");
	gStringFromBytes = e->GetMethodID(gStringClass, "<init>", "([BLjava/lang/String;)V");
	gStringGetBytes = e->GetMethodID(gStringClass, "getBytes", "(Ljava/lang/String;)[B");
	gProgressClass = cls("org/logoshub/sword/SwordNative$ProgressListener");
	gOnProgress = e->GetMethodID(gProgressClass, "onProgress", "(I)V");
	gStatusClass = cls("org/logoshub/sword/SwordNative$StatusListener");
	gOnStatus = e->GetMethodID(gStatusClass, "onStatus", "(Ljava/lang/String;JJ)V");
	gFetcherClass = cls("org/logoshub/sword/SwordNative$HttpFetcher");
	gFetch = e->GetMethodID(gFetcherClass, "fetch",
	                        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;JZLorg/logoshub/sword/SwordNative$HttpHooks;)[B");
	gHttpErrorClass = cls("org/logoshub/sword/SwordNative$HttpError");
	gHttpErrorCode = e->GetFieldID(gHttpErrorClass, "code", "I");
	gHooksClass = cls("org/logoshub/sword/SwordNative$HttpHooks");
	gHooksInit = e->GetMethodID(gHooksClass, "<init>", "(J)V");
	if (e->ExceptionCheck()) return JNI_ERR;
	return JNI_VERSION_1_6;
}

// --- the library ------------------------------------------------------------------------------------------------------------

JNI_FN(jlong, mgrNew)(JNIEnv *e, jclass, jstring path) {
	return (jlong)org_crosswire_sword_SWMgr_newWithPath(fromJ(e, path).c_str());
}
JNI_FN(void, mgrDelete)(JNIEnv *, jclass, jlong mgr) { org_crosswire_sword_SWMgr_delete(H(mgr)); }

JNI_FN(jobjectArray, mgrModuleNames)(JNIEnv *e, jclass, jlong mgr) {
	std::vector<const char *> names;
	for (const auto *info = org_crosswire_sword_SWMgr_getModInfoList(H(mgr)); info && info->name; info++) names.push_back(info->name);
	return toArray(e, names);
}

JNI_FN(jlong, mgrModule)(JNIEnv *e, jclass, jlong mgr, jstring name) {
	return (jlong)org_crosswire_sword_SWMgr_getModuleByName(H(mgr), fromJ(e, name).c_str());
}
JNI_FN(void, mgrSetCipherKey)(JNIEnv *e, jclass, jlong mgr, jstring name, jstring key) {
	org_crosswire_sword_SWMgr_setCipherKey(H(mgr), fromJ(e, name).c_str(), fromJ(e, key).c_str());
}
JNI_FN(void, mgrSetGlobalOption)(JNIEnv *e, jclass, jlong mgr, jstring option, jstring value) {
	org_crosswire_sword_SWMgr_setGlobalOption(H(mgr), fromJ(e, option).c_str(), fromJ(e, value).c_str());
}

JNI_FN(jobjectArray, moduleInfo)(JNIEnv *e, jclass, jlong module) {
	struct swx_module_info info;
	if (swx_module_info(X(module), &info) != 0) return nullptr;
	// the order SwordNative.kt reads: the strings (null stays null), then the flags as "0" or "1"
	std::string flags[8] = {itoa(info.right_to_left), itoa(info.unicode), itoa(info.osis_q_to_tick), itoa(info.verse_keyed),
	                        itoa(info.declares_greek_accents), itoa(info.declares_hebrew_points), itoa(info.declares_cantillation), ""};
	std::vector<const char *> items = {info.source_type, info.versification, info.type, info.category, info.description,
	                                   info.language, info.version, info.cipher_key};
	for (int i = 0; i < 7; i++) items.push_back(flags[i].c_str());
	jobjectArray array = toArray(e, items);
	swx_free_module_info(&info);
	return array;
}

JNI_FN(jstring, moduleConfigEntry)(JNIEnv *e, jclass, jlong module, jstring key) {
	char *value = nullptr;
	if (swx_module_config_entry(X(module), fromJ(e, key).c_str(), &value) != 0 || !value) return nullptr;
	jstring s = toJ(e, value);
	free(value);
	return s;
}

JNI_FN(jboolean, moduleHasFeature)(JNIEnv *e, jclass, jlong module, jstring feature) {
	return swx_module_has_feature(X(module), fromJ(e, feature).c_str()) != 0;
}

JNI_FN(jobjectArray, installFromFolder)(JNIEnv *e, jclass, jlong mgr, jstring folder) {
	int count = 0;
	char **list = swx_install_from_folder(X(mgr), fromJ(e, folder).c_str(), &count);
	return list ? toArrayAndFree(e, list, count) : nullptr;
}

JNI_FN(void, initLocale)(JNIEnv *e, jclass, jstring folder, jobjectArray preferred) {
	std::vector<std::string> languages = arrayToStrings(e, preferred);
	std::vector<const char *> pointers;
	for (auto &s : languages) pointers.push_back(s.c_str());
	swx_init_locale(fromJ(e, folder).c_str(), pointers.data(), (int)pointers.size());
}

// --- reading ----------------------------------------------------------------------------------------------------------------

/// [osis book, chapter number, then for each verse its number and text]
JNI_FN(jobjectArray, readChapter)(JNIEnv *e, jclass, jlong module, jstring reference, jboolean plain) {
	swx_chapter chapter;
	if (swx_read_chapter(X(module), fromJ(e, reference).c_str(), plain ? 1 : 0, &chapter) != 0) return nullptr;
	std::string chapterNumber = itoa(chapter.chapter);
	std::vector<std::string> numbers;
	for (int i = 0; i < chapter.count; i++) numbers.push_back(itoa(chapter.verses[i].verse));
	std::vector<const char *> items = {chapter.osis_book, chapterNumber.c_str()};
	for (int i = 0; i < chapter.count; i++) { items.push_back(numbers[i].c_str()); items.push_back(chapter.verses[i].text); }
	jobjectArray array = toArray(e, items);
	swx_free_chapter(&chapter);
	return array;
}

/// [key as the module names it, raw entry]
JNI_FN(jobjectArray, readEntry)(JNIEnv *e, jclass, jlong module, jstring key) {
	char *found = nullptr, *raw = nullptr;
	if (swx_read_entry(X(module), fromJ(e, key).c_str(), &found, &raw) != 0) return nullptr;
	jobjectArray array = toArray(e, {found, raw});
	free(found);
	free(raw);
	return array;
}

JNI_FN(jstring, readStripped)(JNIEnv *e, jclass, jlong module, jstring key) {
	char *text = nullptr;
	if (swx_read_stripped(X(module), fromJ(e, key).c_str(), &text) != 0 || !text) return nullptr;
	jstring s = toJ(e, text);
	free(text);
	return s;
}

JNI_FN(jobjectArray, dictionaryKeys)(JNIEnv *e, jclass, jlong module) {
	int count = 0;
	char **list = swx_dictionary_keys(X(module), &count);
	return list ? toArrayAndFree(e, list, count) : nullptr;
}

JNI_FN(jobjectArray, parsePassage)(JNIEnv *e, jclass, jstring reference, jstring versification) {
	int count = 0;
	char **list = swx_parse_passage(fromJ(e, reference).c_str(), fromJ(e, versification).c_str(), &count);
	return list ? toArrayAndFree(e, list, count) : nullptr;
}

JNI_FN(jstring, englishBookName)(JNIEnv *e, jclass, jstring name) {
	char *english = swx_english_book_name(fromJ(e, name).c_str());
	jstring s = toJ(e, english);
	free(english);
	return s;
}

JNI_FN(jobjectArray, versificationSystems)(JNIEnv *e, jclass) {
	int count = 0;
	char **list = swx_versification_systems(&count);
	return list ? toArrayAndFree(e, list, count) : nullptr;
}

/// For each book: name, OSIS name, "1" for the New Testament, the number of chapters, then the verses of each chapter.
JNI_FN(jobjectArray, versificationBooks)(JNIEnv *e, jclass, jstring system) {
	swx_versification v;
	if (swx_versification_books(fromJ(e, system).c_str(), &v) != 0) return nullptr;
	size_t total = 0;
	for (int b = 0; b < v.count; b++) total += 2 + (size_t)v.books[b].chapters;
	std::vector<std::string> numbers;
	numbers.reserve(total);   // the pointers below stay valid
	std::vector<const char *> items;
	for (int b = 0; b < v.count; b++) {
		const swx_book &book = v.books[b];
		items.push_back(book.name);
		items.push_back(book.osis_name);
		numbers.push_back(itoa(book.new_testament ? 1 : 0));
		items.push_back(numbers.back().c_str());
		numbers.push_back(itoa(book.chapters));
		items.push_back(numbers.back().c_str());
		for (int c = 0; c < book.chapters; c++) {
			numbers.push_back(itoa(book.verses_per_chapter[c]));
			items.push_back(numbers.back().c_str());
		}
	}
	jobjectArray array = toArray(e, items);
	swx_free_versification(&v);
	return array;
}

// --- searching --------------------------------------------------------------------------------------------------------------

JNI_FN(jboolean, hasSearchIndex)(JNIEnv *, jclass, jlong module) { return swx_has_search_index(X(module)) != 0; }

/// ["1" or "0" for whether the index was used, then the hits]
JNI_FN(jobjectArray, search)(JNIEnv *e, jclass, jlong module, jstring term, jint range, jstring bookReference, jstring versification) {
	int count = 0, usedIndex = 0;
	std::string t = fromJ(e, term), book = fromJ(e, bookReference), system = fromJ(e, versification);
	char **hits = swx_search(X(module), t.c_str(), range, book.c_str(), system.empty() ? nullptr : system.c_str(), &count, &usedIndex);
	if (!hits) return nullptr;
	std::vector<const char *> items = {usedIndex ? "1" : "0"};
	items.insert(items.end(), hits, hits + count);
	jobjectArray array = toArray(e, items);
	swx_free_strings(hits, count);
	return array;
}

JNI_FN(jint, createSearchIndex)(JNIEnv *e, jclass, jlong module, jobject listener) {
	ProgressContext context = {listener};
	return swx_create_search_index(X(module), listener ? progressCallback : nullptr, &context);
}

JNI_FN(void, deleteSearchIndex)(JNIEnv *, jclass, jlong module) { org_crosswire_sword_SWModule_deleteSearchFramework(H(module)); }

// --- installing -------------------------------------------------------------------------------------------------------------

JNI_FN(void, setHttpFetcher)(JNIEnv *e, jclass, jobject fetcher) {
	if (gFetcher) { e->DeleteGlobalRef(gFetcher); gFetcher = nullptr; }
	if (fetcher) {
		gFetcher = e->NewGlobalRef(fetcher);
		swx_set_http_fetch(fetchCallback, nullptr);
	} else {
		swx_set_http_fetch(nullptr, nullptr);
	}
}

// valid only while the fetcher runs: the address SwordNative.HttpHooks was given
JNI_FN(void, hookProgress)(JNIEnv *, jclass, jlong hooks, jlong total, jlong completed) {
	auto *h = (const swx_http_hooks *)(intptr_t)hooks;
	if (h && h->progress) h->progress(h->transport, (unsigned long)total, (unsigned long)completed);
}
JNI_FN(jboolean, hookCancelled)(JNIEnv *, jclass, jlong hooks) {
	auto *h = (const swx_http_hooks *)(intptr_t)hooks;
	return h && h->cancelled && h->cancelled(h->transport) != 0;
}

JNI_FN(jlong, installNew)(JNIEnv *e, jclass, jstring baseDir, jboolean resetSources, jobject listener) {
	StatusContext *context = listener ? new StatusContext{e->NewGlobalRef(listener)} : nullptr;
	SWXHANDLE h = swx_install_new(fromJ(e, baseDir).c_str(), resetSources ? 1 : 0, context ? statusCallback : nullptr, context);
	if (!h) {
		if (context) { e->DeleteGlobalRef(context->listener); delete context; }
		return 0;
	}
	if (context) { std::lock_guard<std::mutex> lock(gStatusMutex); gStatus[h] = context; }
	return (jlong)h;
}

JNI_FN(void, installDelete)(JNIEnv *e, jclass, jlong install) {
	swx_install_delete(X(install));
	std::lock_guard<std::mutex> lock(gStatusMutex);
	auto it = gStatus.find(X(install));
	if (it != gStatus.end()) { e->DeleteGlobalRef(it->second->listener); delete it->second; gStatus.erase(it); }
}

/// For each source: type, caption, host, directory, uid, "1" when packages are tried first.
JNI_FN(jobjectArray, installSources)(JNIEnv *e, jclass, jlong install) {
	int count = 0;
	swx_source *list = swx_install_sources(X(install), &count);
	if (!list) return nullptr;
	std::vector<const char *> items;
	for (int i = 0; i < count; i++) {
		items.insert(items.end(), {list[i].type, list[i].caption, list[i].source, list[i].directory, list[i].uid,
		                           list[i].package_preference ? "1" : "0"});
	}
	jobjectArray array = toArray(e, items);
	swx_free_sources(list, count);
	return array;
}

JNI_FN(jboolean, installAddSource)(JNIEnv *e, jclass, jlong install, jobjectArray fields) {
	std::vector<std::string> f = arrayToStrings(e, fields);
	if (f.size() < 6) return false;
	swx_source source = {const_cast<char *>(f[0].c_str()), const_cast<char *>(f[1].c_str()), const_cast<char *>(f[2].c_str()),
	                     const_cast<char *>(f[3].c_str()), const_cast<char *>(f[4].c_str()), f[5] == "1" ? 1 : 0};
	return swx_install_add_source(X(install), &source) == 0;
}

JNI_FN(jboolean, installRemoveSource)(JNIEnv *e, jclass, jlong install, jstring caption) {
	return swx_install_remove_source(X(install), fromJ(e, caption).c_str()) == 0;
}

JNI_FN(void, installSetDisclaimerConfirmed)(JNIEnv *, jclass, jlong install) {
	org_crosswire_sword_InstallMgr_setUserDisclaimerConfirmed(H(install));
}
JNI_FN(jint, installSyncConfig)(JNIEnv *, jclass, jlong install) { return org_crosswire_sword_InstallMgr_syncConfig(H(install)); }
JNI_FN(jint, installRefresh)(JNIEnv *e, jclass, jlong install, jstring caption) {
	return org_crosswire_sword_InstallMgr_refreshRemoteSource(H(install), fromJ(e, caption).c_str());
}

/// For each remote module: name, description, category, language, version, delta ("*" new, "+" updated, "-" older, "" same).
JNI_FN(jobjectArray, installRemoteModules)(JNIEnv *e, jclass, jlong install, jlong mgr, jstring caption) {
	std::vector<const char *> items;
	const auto *info = org_crosswire_sword_InstallMgr_getRemoteModInfoList(H(install), H(mgr), fromJ(e, caption).c_str());
	for (; info && info->name; info++) {
		items.insert(items.end(), {info->name, info->description, info->category, info->language, info->version, info->delta});
	}
	return toArray(e, items);
}

JNI_FN(jlong, installRemoteModule)(JNIEnv *e, jclass, jlong install, jstring caption, jstring name) {
	return (jlong)org_crosswire_sword_InstallMgr_getRemoteModuleByName(H(install), fromJ(e, caption).c_str(), fromJ(e, name).c_str());
}
JNI_FN(jint, installModule)(JNIEnv *e, jclass, jlong install, jlong mgr, jstring caption, jstring name) {
	return org_crosswire_sword_InstallMgr_remoteInstallModule(H(install), H(mgr), fromJ(e, caption).c_str(), fromJ(e, name).c_str());
}
JNI_FN(jint, installUninstall)(JNIEnv *e, jclass, jlong install, jlong mgr, jstring name) {
	return org_crosswire_sword_InstallMgr_uninstallModule(H(install), H(mgr), fromJ(e, name).c_str());
}
