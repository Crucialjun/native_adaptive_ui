// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to
// build this package.
//
// Deliberately 5.9 rather than 6.0: tools-version 6.0 switches the target to
// the Swift 6 language mode, whose strict concurrency checking rejects the
// non-Sendable UIKit/AppKit and Flutter types this plugin holds across
// callbacks. Moving to 6.0 means auditing every platform-view class for actor
// isolation first; when that happens, bump this line and add
// `swiftSettings: [.swiftLanguageMode(.v6)]` to the target.

import PackageDescription

// Swift Package Manager manifest for the iOS side of the plugin.
//
// Flutter looks for this file at `ios/<plugin_name>/Package.swift`. The target
// name must match the plugin name, and the library product name must be the
// plugin name with underscores replaced by hyphens — Flutter's tooling relies
// on both conventions to wire the package into the app's Xcode project.
//
// The CocoaPods podspec is kept alongside this manifest and points at the same
// `Sources` directory, so the plugin builds under either toolchain from one
// copy of the source. Do not duplicate the Swift files.
let package = Package(
    name: "native_adaptive_ui",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "native-adaptive-ui",
            targets: ["native_adaptive_ui"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "native_adaptive_ui",
            dependencies: [],
            resources: [
                // Apple requires a privacy manifest in every distributed SDK.
                .process("Resources/PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
