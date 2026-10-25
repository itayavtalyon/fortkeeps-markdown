// swift-tools-version: 6.2
import PackageDescription

/// Warnings are errors in the manifest, not through -Xswiftc in the Justfile,
/// so a plain `swift build` matches the gate. Unlike unsafeFlags, this setting
/// does not stop another package from depending on this one.
let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "FortkeepsMarkdown",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "MarkdownCore", targets: ["MarkdownCore"]),
        .library(name: "MarkdownViews", targets: ["MarkdownViews"])
    ],
    dependencies: [
        // A fork of swift-cmark 0.9.0 with the tasklist fix (marker inside a block
        // quote, checked state from the marker). Return to swiftlang/swift-cmark
        // when upstream ships the fix.
        .package(url: "https://github.com/itayavtalyon/swift-cmark.git", exact: "0.9.0-fortkeeps.1")
    ],
    targets: [
        .target(
            name: "MarkdownCore",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark")
            ],
            swiftSettings: strict
        ),
        .target(
            name: "MarkdownViews",
            dependencies: ["MarkdownCore"],
            resources: [.copy("Resources/Fonts")],
            swiftSettings: strict
        ),
        // The tests read Fixtures/ from the checkout, so SwiftPM does not bundle them.
        .testTarget(
            name: "MarkdownCoreTests",
            dependencies: ["MarkdownCore"],
            exclude: ["Fixtures"],
            swiftSettings: strict
        ),
        .testTarget(name: "MarkdownViewsTests", dependencies: ["MarkdownViews"], swiftSettings: strict)
    ]
)
