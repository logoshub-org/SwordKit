# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Logos Hub Ltd
#
# The SWORD core: CrossWire's SWORD engine and our C layer (sword_flat_ext), as one static library with a C API.
# It is built the same way for every platform: for iOS it becomes SwordCore.xcframework (Tools/build_sword_xcframework.sh); for
# Android the same sources build as a shared library per ABI. CLucene is linked beside it, not inside it.

cmake_minimum_required(VERSION 3.22)
project(SwordCore LANGUAGES C CXX)

set(REPO ${CMAKE_CURRENT_SOURCE_DIR}/..)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_library(sword STATIC
    ${CMAKE_CURRENT_SOURCE_DIR}/sword_flat_ext.cpp
    ${REPO}/Vendor/sword/src/frontend/swdisp.cpp
    ${REPO}/Vendor/sword/src/frontend/swlog.cpp
    ${REPO}/Vendor/sword/src/keys/listkey.cpp
    ${REPO}/Vendor/sword/src/keys/strkey.cpp
    ${REPO}/Vendor/sword/src/keys/swkey.cpp
    ${REPO}/Vendor/sword/src/keys/treekey.cpp
    ${REPO}/Vendor/sword/src/keys/treekeyidx.cpp
    ${REPO}/Vendor/sword/src/keys/versekey.cpp
    ${REPO}/Vendor/sword/src/keys/versetreekey.cpp
    ${REPO}/Vendor/sword/src/mgr/encfiltmgr.cpp
    ${REPO}/Vendor/sword/src/mgr/filemgr.cpp
    ${REPO}/Vendor/sword/src/mgr/ftplibftpt.cpp
    ${REPO}/Vendor/sword/src/mgr/installmgr.cpp
    ${REPO}/Vendor/sword/src/mgr/localemgr.cpp
    ${REPO}/Vendor/sword/src/mgr/markupfiltmgr.cpp
    ${REPO}/Vendor/sword/src/mgr/remotetrans.cpp
    ${REPO}/Vendor/sword/src/mgr/rtranspgdrive.cpp
    ${REPO}/Vendor/sword/src/mgr/stringmgr.cpp
    ${REPO}/Vendor/sword/src/mgr/swcacher.cpp
    ${REPO}/Vendor/sword/src/mgr/swconfig.cpp
    ${REPO}/Vendor/sword/src/mgr/swfiltermgr.cpp
    ${REPO}/Vendor/sword/src/mgr/swlocale.cpp
    ${REPO}/Vendor/sword/src/mgr/swmgr.cpp
    ${REPO}/Vendor/sword/src/mgr/swsearchable.cpp
    ${REPO}/Vendor/sword/src/mgr/versificationmgr.cpp
    ${REPO}/Vendor/sword/src/modules/comments/hrefcom/hrefcom.cpp
    ${REPO}/Vendor/sword/src/modules/comments/rawcom/rawcom.cpp
    ${REPO}/Vendor/sword/src/modules/comments/rawcom4/rawcom4.cpp
    ${REPO}/Vendor/sword/src/modules/comments/rawfiles/rawfiles.cpp
    ${REPO}/Vendor/sword/src/modules/comments/swcom.cpp
    ${REPO}/Vendor/sword/src/modules/comments/zcom/zcom.cpp
    ${REPO}/Vendor/sword/src/modules/comments/zcom4/zcom4.cpp
    ${REPO}/Vendor/sword/src/modules/common/bz2comprs.cpp
    ${REPO}/Vendor/sword/src/modules/common/entriesblk.cpp
    ${REPO}/Vendor/sword/src/modules/common/ioapi.c
    ${REPO}/Vendor/sword/src/modules/common/lzsscomprs.cpp
    ${REPO}/Vendor/sword/src/modules/common/rawstr.cpp
    ${REPO}/Vendor/sword/src/modules/common/rawstr4.cpp
    ${REPO}/Vendor/sword/src/modules/common/rawverse.cpp
    ${REPO}/Vendor/sword/src/modules/common/rawverse4.cpp
    ${REPO}/Vendor/sword/src/modules/common/sapphire.cpp
    ${REPO}/Vendor/sword/src/modules/common/swcipher.cpp
    ${REPO}/Vendor/sword/src/modules/common/swcomprs.cpp
    ${REPO}/Vendor/sword/src/modules/common/unzip.c
    ${REPO}/Vendor/sword/src/modules/common/zipcomprs.cpp
    ${REPO}/Vendor/sword/src/modules/common/zstr.cpp
    ${REPO}/Vendor/sword/src/modules/common/zverse.cpp
    ${REPO}/Vendor/sword/src/modules/common/zverse4.cpp
    ${REPO}/Vendor/sword/src/modules/filters/cipherfil.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbffootnotes.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfheadings.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfhtml.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfhtmlhref.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbflatex.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfmorph.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfosis.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfplain.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfredletterwords.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfrtf.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfstrongs.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfthml.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfwebif.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfwordjs.cpp
    ${REPO}/Vendor/sword/src/modules/filters/gbfxhtml.cpp
    ${REPO}/Vendor/sword/src/modules/filters/greeklexattribs.cpp
    ${REPO}/Vendor/sword/src/modules/filters/latin1utf16.cpp
    ${REPO}/Vendor/sword/src/modules/filters/latin1utf8.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisenum.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisfootnotes.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisglosses.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisheadings.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osishtmlhref.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osislatex.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osislemma.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osismorph.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osismorphsegmentation.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisosis.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisplain.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisredletterwords.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisreferencelinks.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisrtf.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisscripref.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisstrongs.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisvariants.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osiswebif.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osiswordjs.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisxhtml.cpp
    ${REPO}/Vendor/sword/src/modules/filters/osisxlit.cpp
    ${REPO}/Vendor/sword/src/modules/filters/papyriplain.cpp
    ${REPO}/Vendor/sword/src/modules/filters/rtfhtml.cpp
    ${REPO}/Vendor/sword/src/modules/filters/scsuutf8.cpp
    ${REPO}/Vendor/sword/src/modules/filters/swbasicfilter.cpp
    ${REPO}/Vendor/sword/src/modules/filters/swoptfilter.cpp
    ${REPO}/Vendor/sword/src/modules/filters/teihtmlhref.cpp
    ${REPO}/Vendor/sword/src/modules/filters/teilatex.cpp
    ${REPO}/Vendor/sword/src/modules/filters/teiplain.cpp
    ${REPO}/Vendor/sword/src/modules/filters/teirtf.cpp
    ${REPO}/Vendor/sword/src/modules/filters/teixhtml.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlfootnotes.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlgbf.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlheadings.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlhtml.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlhtmlhref.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmllatex.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmllemma.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlmorph.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlosis.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlplain.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlrtf.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlscripref.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlstrongs.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlvariants.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlwebif.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlwordjs.cpp
    ${REPO}/Vendor/sword/src/modules/filters/thmlxhtml.cpp
    ${REPO}/Vendor/sword/src/modules/filters/unicodertf.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf16utf8.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8arabicpoints.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8arshaping.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8bidireorder.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8cantillation.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8greekaccents.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8hebrewpoints.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8html.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8latin1.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8nfc.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8nfkd.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8scsu.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8transliterator.cpp
    ${REPO}/Vendor/sword/src/modules/filters/utf8utf16.cpp
    ${REPO}/Vendor/sword/src/modules/genbook/rawgenbook/rawgenbook.cpp
    ${REPO}/Vendor/sword/src/modules/genbook/swgenbook.cpp
    ${REPO}/Vendor/sword/src/modules/lexdict/rawld/rawld.cpp
    ${REPO}/Vendor/sword/src/modules/lexdict/rawld4/rawld4.cpp
    ${REPO}/Vendor/sword/src/modules/lexdict/swld.cpp
    ${REPO}/Vendor/sword/src/modules/lexdict/zld/zld.cpp
    ${REPO}/Vendor/sword/src/modules/swmodule.cpp
    ${REPO}/Vendor/sword/src/modules/texts/rawtext/rawtext.cpp
    ${REPO}/Vendor/sword/src/modules/texts/rawtext4/rawtext4.cpp
    ${REPO}/Vendor/sword/src/modules/texts/swtext.cpp
    ${REPO}/Vendor/sword/src/modules/texts/ztext/ztext.cpp
    ${REPO}/Vendor/sword/src/modules/texts/ztext4/ztext4.cpp
    ${REPO}/Vendor/sword/src/utilfuns/ftplib.c
    ${REPO}/Vendor/sword/src/utilfuns/ftpparse.c
    ${REPO}/Vendor/sword/src/utilfuns/roman.cpp
    ${REPO}/Vendor/sword/src/utilfuns/swbuf.cpp
    ${REPO}/Vendor/sword/src/utilfuns/swobject.cpp
    ${REPO}/Vendor/sword/src/utilfuns/swversion.cpp
    ${REPO}/Vendor/sword/src/utilfuns/url.cpp
    ${REPO}/Vendor/sword/src/utilfuns/utilstr.cpp
    ${REPO}/Vendor/sword/src/utilfuns/utilxml.cpp
)

target_include_directories(sword PRIVATE ${REPO}/Vendor/sword/include ${CMAKE_CURRENT_SOURCE_DIR} ${CLUCENE_HEADERS})
# What the SWORD sources have always been built with (they test these without including config.h).
target_compile_definitions(sword PRIVATE USELUCENE=1 CLUCENE2=1 unix=1 __unix__=1 EXCLUDEXZ=1)
target_compile_options(sword PRIVATE -Wno-shorten-64-to-32 -Wno-invalid-source-encoding)

# Android: no bzip2 yet. The NDK has no libbz2, and SWORD can leave it out (swmgr.cpp, EXCLUDEBZIP2): a module compressed with bzip2 will not
# open there. Everything else is as on iOS (LZSS is SWORD's own; zlib is the NDK's -lz; ICU is not used, _ICU_ is never defined).
if(ANDROID)
    get_target_property(SWORD_SOURCES sword SOURCES)
    list(FILTER SWORD_SOURCES EXCLUDE REGEX "bz2comprs\\.cpp$")
    set_property(TARGET sword PROPERTY SOURCES ${SWORD_SOURCES})
    # IOAPI_NO_64: minizip (ioapi.c) takes the plain fopen, fseeko and ftello (off_t is 64-bit on 64-bit Android; bionic has no fopen64 there)
    target_compile_definitions(sword PRIVATE EXCLUDEBZIP2=1 IOAPI_NO_64=1)

    # The one library the app loads: SWORD (taken whole) and CLucene, static archives, in one .so.
    # CLUCENE_LIB is CLucene's libclucene.a for this ABI.
    if(NOT CLUCENE_LIB)
        message(FATAL_ERROR "set CLUCENE_LIB to the libclucene.a built for this ABI")
    endif()
    # The JNI over the C layer (android/sword_jni.cpp); the Kotlin class is org.logoshub.sword.SwordNative (Android/). Only JNI, the flat
    # API and the swx_* functions are exported (android/exports.map): SWORD's and CLucene's own symbols are not.
    add_library(sword_android SHARED ${CMAKE_CURRENT_SOURCE_DIR}/android/sword_jni.cpp)
    target_include_directories(sword_android PRIVATE ${REPO}/Vendor/sword/include ${CMAKE_CURRENT_SOURCE_DIR})
    target_link_libraries(sword_android PRIVATE
        -Wl,--whole-archive sword -Wl,--no-whole-archive ${CLUCENE_LIB}
        -Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/android/exports.map -Wl,--gc-sections
        z log)
    set_target_properties(sword_android PROPERTIES OUTPUT_NAME sword_android)
endif()
