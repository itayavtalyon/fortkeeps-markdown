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
    targets: [
        .target(name: "MarkdownCore", swiftSettings: strict),
        .target(
            name: "MarkdownViews",
            dependencies: ["MarkdownCore"],
            resources: [.copy("Resources/Fonts")],
            swiftSettings: strict
        ),
        .testTarget(name: "MarkdownCoreTests", dependencies: ["MarkdownCore"], swiftSettings: strict),
        .testTarget(name: "MarkdownViewsTests", dependencies: ["MarkdownViews"], swiftSettings: strict)
    ]
)
