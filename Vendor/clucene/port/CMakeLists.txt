cmake_minimum_required(VERSION 3.21)
project(CLucene VERSION 2.3.3.4 LANGUAGES C CXX)

if(NOT ANDROID AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS" AND NOT UNIX)
    message(FATAL_ERROR "This configuration supports iOS, Android, and POSIX hosts only.")
endif()

include(GNUInstallDirs)
include(cmake/Sources.cmake)
find_package(Threads REQUIRED)

option(CLUCENE_BUILD_HIGHLIGHTER "Include the optional highlighter in libclucene" OFF)
option(CLUCENE_BUILD_TESTS "Build the indexing/search smoke test" OFF)

set(CLUCENE_GENERATED_INCLUDE "${CMAKE_CURRENT_BINARY_DIR}/generated/include")
file(MAKE_DIRECTORY "${CLUCENE_GENERATED_INCLUDE}/CLucene")
configure_file(cmake/config/clucene-config.h.in
    "${CLUCENE_GENERATED_INCLUDE}/CLucene/clucene-config.h" @ONLY)
configure_file(cmake/config/_clucene-config.h.in
    "${CLUCENE_GENERATED_INCLUDE}/CLucene/_clucene-config.h" @ONLY)

add_library(clucene STATIC ${CLUCENE_CORE_SOURCES} ${CLUCENE_SHARED_SOURCES})
add_library(CLucene::clucene ALIAS clucene)
set_target_properties(clucene PROPERTIES
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
    POSITION_INDEPENDENT_CODE YES)
target_include_directories(clucene PUBLIC
    $<BUILD_INTERFACE:${CLUCENE_GENERATED_INCLUDE}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/core>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/shared>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_compile_definitions(clucene PUBLIC
    _REENTRANT _UCS2 _UNICODE MAKE_CLUCENE_CORE_LIB MAKE_CLUCENE_SHARED_LIB)
target_compile_options(clucene PRIVATE
    $<$<COMPILE_LANG_AND_ID:CXX,Clang,AppleClang,GNU>:-fexceptions>)
if(APPLE)
    target_compile_options(clucene PUBLIC $<$<COMPILE_LANGUAGE:CXX>:-stdlib=libc++>)
    target_link_options(clucene INTERFACE -stdlib=libc++)
endif()
target_link_libraries(clucene PUBLIC Threads::Threads z)

if(CLUCENE_BUILD_HIGHLIGHTER)
    target_sources(clucene PRIVATE ${CLUCENE_HIGHLIGHTER_SOURCES})
    target_include_directories(clucene PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/contribs>)
    target_compile_definitions(clucene PUBLIC MAKE_CLUCENE_CONTRIBS_LIB)
    install(DIRECTORY src/contribs/CLucene/highlighter
        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/CLucene"
        FILES_MATCHING PATTERN "*.h")
endif()

install(TARGETS clucene EXPORT CLuceneTargets
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
install(FILES include/CLucene.h DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
install(DIRECTORY src/core/CLucene src/shared/CLucene
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}" FILES_MATCHING PATTERN "*.h")
install(FILES "${CLUCENE_GENERATED_INCLUDE}/CLucene/clucene-config.h"
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/CLucene")
install(EXPORT CLuceneTargets NAMESPACE CLucene::
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/CLucene")
include(CMakePackageConfigHelpers)
configure_package_config_file(cmake/CLuceneConfig.cmake.in
    "${CMAKE_CURRENT_BINARY_DIR}/CLuceneConfig.cmake"
    INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/CLucene")
write_basic_package_version_file("${CMAKE_CURRENT_BINARY_DIR}/CLuceneConfigVersion.cmake"
    VERSION "${PROJECT_VERSION}" COMPATIBILITY SameMajorVersion)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/CLuceneConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/CLuceneConfigVersion.cmake"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/CLucene")
install(FILES LICENSE DESTINATION "${CMAKE_INSTALL_DATADIR}/CLucene")

if(CLUCENE_BUILD_TESTS)
    enable_testing()
    add_executable(clucene-smoke tests/smoke.cpp)
    target_link_libraries(clucene-smoke PRIVATE CLucene::clucene)
    add_test(NAME clucene-smoke COMMAND clucene-smoke)
endif()