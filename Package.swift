// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "nugu-ios",
    platforms: [
        .iOS(.v13),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "nugu-ios",
            targets: ["NuguClientKit", "NuguAgents", "NuguUtils", "NuguServiceKit", "NuguLoginKit", "KeenSense", "NuguCore"]
        ),
        .library(
            name: "nugu-core",
            targets: ["NuguUtils", "NuguCore", "SilverTray"]
        )
    ],
    dependencies: [
        .package(name: "RxSwift", url: "https://github.com/ReactiveX/RxSwift", from: "6.0.0"),
        .package(name: "NattyLog", url: "https://github.com/AgentiOS/natty-log-ios", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "NuguUtils",
            dependencies: ["RxSwift"],
            path: "NuguUtils/",
            exclude: ["Info.plist"]
        ),
        .target(
            name: "NuguObjcUtils",
            dependencies: [],
            path: "NuguObjcUtils/",
            exclude: ["Info.plist"]
        ),
        .binaryTarget(
            name: "TycheCommon",
            path: "TycheCommon.xcframework"
        ),
        .binaryTarget(
            name: "TycheEpd",
            path: "TycheEpd.xcframework"
        ),
        .binaryTarget(
            name: "TycheWakeup",
            path: "TycheWakeup.xcframework"
        ),
        .binaryTarget(
            name: "TycheSpeex",
            path: "TycheSpeex.xcframework"
        ),
        .target(
            name: "TycheSDK",
            dependencies: ["TycheCommon", "TycheEpd", "TycheWakeup", "TycheSpeex"],
            path: "TycheSDK/",
            exclude: ["Info.plist"],
            publicHeadersPath: "include/"
        ),
        .target(
            name: "JadeMarble",
            dependencies: ["NattyLog", "TycheSDK", "TycheCommon", "TycheEpd", "TycheSpeex"],
            path: "JadeMarble/",
            exclude: ["Info.plist"],
            resources: [.process("Resources/skt_epd_model.raw")],
            linkerSettings: [.linkedLibrary("c++")]
        ),
        .target(
            name: "KeenSense",
            dependencies: ["NattyLog", "NuguUtils", "TycheSDK"],
            path: "KeenSense/",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources/skt_trigger_search_aria.raw"),
                .process("Resources/skt_trigger_search_tinkerbell.raw"),
                .process("Resources/skt_trigger_am_aria.raw"),
                .process("Resources/skt_trigger_am_tinkerbell.raw")
            ],
            linkerSettings: [.linkedLibrary("c++")]
        ),
        .target(
            name: "NuguCore",
            dependencies: ["NuguUtils", "NuguObjcUtils", "NattyLog"],
            path: "NuguCore/",
            exclude: ["Info.plist", "README.md"]
        ),
        .binaryTarget(
            name: "OpusCodec",
            path: "OpusCodec.xcframework"
        ),
        .target(
            name: "OpusSDK",
            dependencies: ["OpusCodec"],
            path: "OpusSDK/",
            exclude: ["Info.plist"],
            publicHeadersPath: "include/"
        ),
        .target(
            name: "SilverTray",
            dependencies: ["NuguUtils", "NuguObjcUtils", "OpusSDK"],
            path: "SilverTray/",
            exclude: ["Info.plist"],
            publicHeadersPath: "inlcude/"
        ),
        .target(
            name: "NuguAgents",
            dependencies: ["NuguUtils", "NuguCore", "JadeMarble", "KeenSense", "RxSwift", "NattyLog", "SilverTray"],
            path: "NuguAgents/",
            exclude: ["Info.plist", "README.md"]
        ),
        .target(
            name: "NuguServiceKit",
            dependencies: ["NattyLog", "NuguUtils"],
            path: "NuguServiceKit/",
            exclude: ["Info.plist", "README.md"]
        ),
        .target(
            name: "NuguLoginKit",
            dependencies: ["NuguUtils", "NattyLog"],
            path: "NuguLoginKit/",
            exclude: ["Info.plist", "README.md"]
        ),
        .target(
            name: "NuguClientKit",
            dependencies: ["NuguAgents", "NattyLog", "RxSwift", "NuguUtils", "NuguServiceKit", "NuguLoginKit", "KeenSense", "NuguCore"],
            path: "NuguClientKit/",
            exclude: ["Info.plist", "README.md"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
