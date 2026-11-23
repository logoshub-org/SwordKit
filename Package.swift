// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd
import PackageDescription
import Foundation

// SwordKit: the SWORD engine and CLucene, with a C extension layer and a Swift API over them, for iOS.
//
// Two prebuilt binaries, both built from sources in this repository:
//  - SwordCore.xcframework: SWORD and our C layer (sword_flat_ext). It changes whenever SWORD or the layer does, and is attached to each
//    SwordKit release (Tools/build_sword_xcframework.sh builds it and prints its checksum).
//  - CLucene.xcframework: CLucene 2.3.3.4, SWORD's search library. It does not change, so it has a release of its own, `clucene-2.3.3.4`,
//    that every SwordKit version names: SwiftPM downloads it once and caches it (Tools/build_clucene_xcframework.sh).
// Put each URL's real checksum below (the build scripts print them).
//
// Working on SwordKit itself: set SWORDKIT_LOCAL=1 to use build/SwordCore.xcframework and build/CLucene.xcframework.
let local = ProcessInfo.processInfo.environment["SWORDKIT_LOCAL"] != nil

let swordCore: Target = local
    ? .binaryTarget(name: "SwordCore", path: "build/SwordCore.xcframework")
    : .binaryTarget(
        name: "SwordCore",
        url: "https://github.com/logoshub-org/SwordKit/releases/download/0.1.2/SwordCore.xcframework.zip",
        checksum: "bef4244f84b7b55bd276d6a4c85ece10a4d74706872d6d9666ba5534c36fe88d")

let cLucene: Target = local
    ? .binaryTarget(name: "CLucene", path: "build/CLucene.xcframework")
    : .binaryTarget(
        name: "CLucene",
        url: "https://github.com/logoshub-org/SwordKit/releases/download/clucene-2.3.3.4/CLucene.xcframework.zip",
        checksum: "354897bc984d6ca2b4cbf622c09dc312a967497e04d94325fdc8316a22736efe")

let package = Package(
    name: "SwordKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        // The installed modules, reads, search, locked modules, and the install manager with its HTTP host.
        .library(name: "SwordProvider", targets: ["SwordProvider"]),
    ],
    targets: [
        swordCore,
        cLucene,
        .target(
            name: "SwordProvider",
            dependencies: ["SwordCore", "CLucene"],
            // SWORD and CLucene need the system's ICU, C++ library, zlib and bzip2
            linkerSettings: [.linkedLibrary("icucore"), .linkedLibrary("c++"), .linkedLibrary("z"), .linkedLibrary("bz2")]
        ),
        // Swift-only checks of the API that need no modules (the About page's fields); run on an iOS simulator.
        .testTarget(name: "SwordProviderTests", dependencies: ["SwordProvider"]),
    ],
    swiftLanguageModes: [.v5]
)
